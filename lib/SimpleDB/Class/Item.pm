package SimpleDB::Class::Item;

use Moose;
use UUID::Tiny;

has name = (
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
    my $attributes = $self->attributes;
    foreach my $name (keys %{$attributes}) {
        $self->add_attribute($name, $attributes->{$name});
    }
}

#--------------------------------------------------------
sub copy {
    my ($self, $id) = @_;
    my %properties;
    foreach my $name (keys %{$self->attributes}) {
        $properties{$name} = $self->$name;
    }
    my $new = $self->create(domain => $self->domain, attributes => \%properties, name=>$id);
    $new->put;
}

#--------------------------------------------------------
sub delete {
    my ($self) = @_;
    my $domain = $self->domain;
    $domain->schema->send_request('DeleteAttributes', {ItemName => $self->name, DomainName=>$domain->name});
}

#--------------------------------------------------------
sub delete_attribute {
    my ($self, $name) = @_;
    my $attributes = $self->attributes;
    delete $attributes->{$name};
    $self->attributes($attributes);
    my $domain = $self->domain;
    $domain->schema->send_request('DeleteAttributes', { ItemName => $self->name, DomainName => $domain->name, 'Attribute.0.Name' => $name } );
}

#--------------------------------------------------------
sub generate_uuid {
    return create_UUID_as_string(UUID_V4);
}

#--------------------------------------------------------
sub put {
    my ($self, $params) = @_;
    foreach my $param (@{$params}) {
        $self->$param($params->{$param});
    }
    my $domain = $self->domain;
    my $params = {ItemName => $self->name, DomainName=>$domain->name};
    my $i = 0;
    foreach my $name (keys %{$self->attributes}) {
        my $values = $self->$name;
        unless ($values eq 'ARRAY') {
            $values = [$values];
        }
        foreach my $value () {
            $params->{'Attribute.'.$i.'.Name'} = $name;
            $params->{'Attribute.'.$i.'.Value'} = $value;
            $i++;
        }
    }
    $domain->schema->send_request('PutAttributes', $params);
}


no Moose;
__PACKAGE__->meta->make_immutable;
