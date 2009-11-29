package SimpleDB::Class::Domain;

use Moose;
use MooseX::ClassAttribute;
use SimpleDB::Class::Item;
use SimpleDB::Class::Select;


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
sub find {
    my ($self, $id) = @_;
    my $result = $self->simpledb->send_request('GetAttributes', {
        ItemName => $id
    });
    my $list = $result->{GetAttributesResult}{Attribute};
    unless (ref $list eq 'ARRAY') {
        $list = [$list];
    }
    my %attributes;
    foreach my $attribute (@{$list}) {
        if (exists $attributes{$attribute->{Name}}) {
            if (ref $attributes{$attribute->{Name}} ne 'ARRAY') {
                $attributes{$attribute->{Name}} = [$attributes{$attribute->{Name}}];
            }
            push @{$attributes{$attribute->{Name}}}, $attribute->{Value};
        }
        else {
            $attributes{$attribute->{Name}} = $attribute->{Value};
        }
    }
    return SimpleDB::Class::Item->new(domain=>$self, name=>$id, attributes=>\%attributes);
}

#--------------------------------------------------------
sub insert {
    my ($self, $attributes, $id) = @_;
    my $item = SimpleDB::Class::Item->new(domain=>$self, attributes=>$attributes, name=>$id);
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
    my ($self) = @_;
}

no Moose;
__PACKAGE__->meta->make_immutable;
