package SimpleDB::Class::Domain;

use Moose;
use MooseX::ClassAttribute;
use SimpleDB::Class::Item;
use SimpleDB::Class::Select;
use SimpleDB::Class::ResultSet;

class_has 'name' => (
    is      => 'rw',
    trigger => sub {
        my ($class, $new, $old) = @_;
        SimpleDB::Class->add_domain_alias($new => $class);
        },
);

has 'simpledb' => (
    is          => 'ro',
    required    => 1,
);

class_has 'attributes' => (
    is      => 'rw',
    isa     => 'ArrayRef',
    default => sub{[]},
);

#--------------------------------------------------------
sub add_attributes {
    my ($class, @new_attributes) = @_;
    my @attributes = (@{$class->attributes}, @new_attributes);
    $class->attributes(\@attributes);
    return \@attributes;
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
    return SimpleDB::Class::ResultSet->handle_item($self, $id, $list);
}

#--------------------------------------------------------
sub insert {
    my ($self, $attributes, $id) = @_;
    my %params = (domain=>$self, attributes=>$attributes);
    if (defined $id && $id ne '') {
        $params{name} = $id;
    }
    my $item = SimpleDB::Class::Item->new(\%params);
    $item->put;
    return $item;
}

#--------------------------------------------------------
sub count {
    my ($self, $clauses) = @_;
    my $select = SimpleDB::Class::Select->new(
        domain_name => $self->name,
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

no Moose;
__PACKAGE__->meta->make_immutable;
