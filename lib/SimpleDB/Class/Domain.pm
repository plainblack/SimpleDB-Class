package SimpleDB::Class::Domain;

use Moose;
use MooseX::ClassAttribute;
use SimpleDB::Class::Item;
use SimpleDB::Class::Select;
use SimpleDB::Class::ResultSet;


sub set_name {
    my ($class, $name) = @_;
    SimpleDB::Class->_add_domain($name => $class->new(name=>$name));
}
#class_has 'name' => (
#    is      => 'rw',
#    trigger => sub {
#        my ($class, $new, $old) = @_;
#        SimpleDB::Class->add_domain_alias($new => $class);
#        },
#);

has 'name' => (
    is          => 'ro',
    required    => 1,
);

has 'simpledb' => (
    is          => 'rw',
);

has 'attributes' => (
    is      => 'rw',
    isa     => 'ArrayRef',
    default => sub{[]},
);

class_has '_parents' => (
    is      => 'rw',
    isa     => 'HashRef',
    default => sub{{}},
);

class_has '_children' => (
    is      => 'rw',
    isa     => 'HashRef',
    default => sub{{}},
);

#--------------------------------------------------------
sub belongs_to {
    my ($class, $name, $classname, $attribute) = @_;
    my $parents = $class->_parents;
    $parents->{$name} = [$classname, $attribute];
    $class->_parents($parents);
};

#--------------------------------------------------------
sub has_many {
    my ($class, $name, $classname, $attribute) = @_;
    my $children = $class->_children;
    $children->{$name} = [$classname, $attribute];
    $class->_children($children);
};

#--------------------------------------------------------
sub add_attributes {
    my ($class, @new_attributes) = @_;
    my $self = SimpleDB::Class->determine_domain_instance($class);
    my @attributes = (@{$self->attributes}, @new_attributes);
    $self->attributes(\@attributes);
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
