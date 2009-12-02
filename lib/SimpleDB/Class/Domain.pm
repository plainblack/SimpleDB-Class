package SimpleDB::Class::Domain;

=head1 NAME



=head1 DESCRIPTION



=head1 METHODS

The following methods are available from this class.

=cut

use Moose;
use SimpleDB::Class::Item;
use SimpleDB::Class::SQL;
use SimpleDB::Class::ResultSet;


#--------------------------------------------------------
sub set_name {
    my ($class, $name) = @_;
    SimpleDB::Class->_add_domain($name => $class->new(name=>$name));
}

has 'name' => (
    is          => 'ro',
    required    => 1,
);

has 'simpledb' => (
    is          => 'rw',
);

has 'attributes' => (
    is      => 'rw',
    isa     => 'HashRef',
    default => sub{{}},
);

has 'parents' => (
    is      => 'rw',
    isa     => 'HashRef',
    default => sub{{}},
);

has 'children' => (
    is      => 'rw',
    isa     => 'HashRef',
    default => sub{{}},
);

#--------------------------------------------------------
sub belongs_to {
    my ($class, $name, $classname, $attribute) = @_;
    my $self = SimpleDB::Class->determine_domain_instance($class);
    my $parents = $self->parents;
    $parents->{$name} = [$classname, $attribute];
    $self->parents($parents);
};

#--------------------------------------------------------
sub has_many {
    my ($class, $name, $classname, $attribute) = @_;
    my $self = SimpleDB::Class->determine_domain_instance($class);
    my $children = $self->children;
    $children->{$name} = [$classname, $attribute];
    $self->children($children);
};

#--------------------------------------------------------
sub add_attributes {
    my ($class, %new_attributes) = @_;
    my $self = SimpleDB::Class->determine_domain_instance($class);
    my %attributes = (%{$self->attributes}, %new_attributes);
    $self->attributes(\%attributes);
    return \%attributes;
}

#--------------------------------------------------------
sub create {
    my ($self) = @_;
    $self->simpledb->send_request('CreateDomain', {
        DomainName => $self->name,
    });
}

#--------------------------------------------------------
sub delete {
    my ($self) = @_;
    $self->simpledb->send_request('DeleteDomain', {
        DomainName => $self->name,
    });
}

#--------------------------------------------------------
sub find {
    my ($self, $id) = @_;
    my $result = $self->simpledb->send_request('GetAttributes', {
        ItemName    => $id,
        DomainName  => $self->name,
    });
    my $list = $result->{GetAttributesResult}{Attribute};
    return SimpleDB::Class::ResultSet->new(domain=>$self)->handle_item($id, $list);
}

#--------------------------------------------------------
sub insert {
    my ($self, $attributes, $id) = @_;
    my %params = (domain=>$self, attributes=>$attributes);
    if (defined $id && $id ne '') {
        $params{id} = $id;
    }
    my $item = SimpleDB::Class::Item->new(\%params);
    $item->put;
    return $item;
}

#--------------------------------------------------------
sub count {
    my ($self, $clauses) = @_;
    my $select = SimpleDB::Class::SQL->new(
        domain      => $self,
        where       => $clauses,
        output      => 'count(*)',
    );
    my $result = $self->simpledb->send_request('Select', {
        SelectExpression    => $select->to_sql,
    });
    return $result->{SelectResult}{Item}{Attribute}{Value};
}

#--------------------------------------------------------
sub search {
    my ($self, $where) = @_;
    return SimpleDB::Class::ResultSet->new(
        domain      => $self,
        where       => $where,
        );
}

=head1 AUTHOR

JT Smith <jt_at_plainblack_com>

I have to give credit where credit is due: SimpleDB::Class is heavily inspired by L<DBIx::Class> by Matt Trout (and others), and the Amazon::SimpleDB class distributed by Amazon itself (not to be confused with Amazon::SimpleDB written by Timothy Appnel).

=head1 LEGAL

SimpleDB::Class is Copyright 2009 Plain Black Corporation and is licensed under the same terms as Perl itself.

=cut

no Moose;
__PACKAGE__->meta->make_immutable;
