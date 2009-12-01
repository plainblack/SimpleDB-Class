package SimpleDB::Class::Item;

use Moose;
use UUID::Tiny;
use SimpleDB::Class::SQL;

has id => (
    is          => 'ro',
    builder     => 'generate_uuid',
    lazy        => 1,
);

has domain => (
    is          => 'ro',
    required    => 1,
);

has attributes => (
    is          => 'rw',
    isa         => 'HashRef',
    required    => 1,
);

#--------------------------------------------------------
sub add_attribute {
    my ($self, $name, $value) = @_;
    my $attributes = $self->attributes;
    $attributes->{$name} = $value;
    $self->attributes($attributes);
    has $name => (
        is      => 'rw',
        default => $value,
        lazy    => 1,
    );
}

#--------------------------------------------------------
sub BUILD {
    my ($self) = @_;
    my $domain = $self->domain;

    # add attributes
    my $registered_attributes = $domain->attributes;
    my $attributes = $self->attributes;
    my $select = SimpleDB::Class::SQL->new(domain=>$domain);
    foreach my $name (keys %{$attributes}) {
        my %params = (
            is      => 'rw',
            default => $select->format_value($name, $attributes->{$name}),
            lazy    => 1,
        );
        if (exists $registered_attributes->{$name}{isa}) {
            $params{isa} = $registered_attributes->{$name}{isa};
        }
        has $name => (%params);
    }

    # add parents
    my $parents = $domain->parents;
    foreach my $parent (keys %{$parents}) {
        my ($classname, $attribute) = @{$parents->{$parent}};
        has $parent => (
            is      => 'ro',
            default => sub {
                my $self = shift;
                return $domain->simpledb->determine_domain_instance($classname)->find($self->$attribute);
                },
            lazy    => 1,
        );
    }

    # add children
    my $children = $domain->children;
    foreach my $child (keys %{$children}) {
        my ($classname, $attribute) = @{$children->{$child}};
        has $child => (
            is      => 'ro',
            default => sub {
                my $self = shift;
                return $domain->simpledb->determine_domain_instance($classname)->search({$attribute => $self->$attribute});
                },
            lazy    => 1,
        );
    }
}

#--------------------------------------------------------
sub copy {
    my ($self, $id) = @_;
    my %properties;
    foreach my $name (keys %{$self->attributes}) {
        $properties{$name} = $self->$name;
    }
    my $new = $self->new(domain => $self->domain, attributes => \%properties, id=>$id);
    $new->put;
}

#--------------------------------------------------------
sub delete {
    my ($self) = @_;
    my $domain = $self->domain;
    $domain->simpledb->send_request('DeleteAttributes', {ItemName => $self->id, DomainName=>$domain->name});
}

#--------------------------------------------------------
sub delete_attribute {
    my ($self, $name) = @_;
    my $attributes = $self->attributes;
    delete $attributes->{$name};
    $self->attributes($attributes);
    my $domain = $self->domain;
    $domain->simpledb->send_request('DeleteAttributes', { ItemName => $self->id, DomainName => $domain->name, 'Attribute.0.Name' => $name } );
}

#--------------------------------------------------------
sub generate_uuid {
    return create_UUID_as_string(UUID_V4);
}

#--------------------------------------------------------
sub put {
    my ($self, $attributes) = @_;
    my $registered_attributes = $self->attributes;

    foreach my $attribute (@{$attributes}) {
        $self->$attribute($attributes->{$attribute});
    }
    my $domain = $self->domain;
    my $params = {ItemName => $self->id, DomainName=>$domain->name};
    my $i = 0;
    my $select = SimpleDB::Class::SQL->new(domain=>$self->domain); 
    foreach my $name (keys %{$self->attributes}) {
        my $values = $self->$name;
        unless ($values eq 'ARRAY') {
            $values = [$values];
        }
        foreach my $value (@{$values}) {
            $value = $select->format_value($name, $value);
            $params->{'Attribute.'.$i.'.Name'} = $name;
            $params->{'Attribute.'.$i.'.Value'} = $value;
            $i++;
        }
    }
    $domain->simpledb->send_request('PutAttributes', $params);
}


1;
