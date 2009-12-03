package SimpleDB::Class::Item;

=head1 NAME

SimpleDB::Class::Item - An object representation from an item in a SimpleDB domain.

=head1 DESCRIPTION

An object representation from an item in a SimpleDB domain.

=head1 METHODS

The following methods are available from this class.

=cut

use Moose;
use UUID::Tiny;
use SimpleDB::Class::SQL;

#--------------------------------------------------------

=head2 new ( params )

Constructor.

=head3 params

A hash.

=head4 id

The unique identifier (ItemName) of the item represented by this class. If you don't pass this in, an item ID will be generated for you automatically.

=head4 domain

Required. A L<SimpleDB::Class::Domain> object.

=head4 attributes

Required. A hashref containing the names and values of the attributes associated with this item.

=head2 {attribute} ( [ value ] )

For each attribute passed into the constructor, an accessor / mutator will be added to this class allowing you to get or set it's current value.

=head3

If specified, sets the current value of the attribute. Note, that this doesn't update the database, for that you must call the put() method.

=cut

#--------------------------------------------------------

=head2 id ( )

Returns the unique id of this item.

=cut

has id => (
    is          => 'ro',
    builder     => 'generate_uuid',
    lazy        => 1,
);

#--------------------------------------------------------

=head2 domain ( )

Returns the domain passed into the constructor.

=cut

has domain => (
    is          => 'ro',
    required    => 1,
);

#--------------------------------------------------------

=head2 attributes ( )

Returns the attributes passed into the constructor.

=cut

has attributes => (
    is          => 'rw',
    isa         => 'HashRef',
    required    => 1,
);

#--------------------------------------------------------

=head2 add_attribute ( name, [ default, type ] )

Adds an accessor / mutator for a new attribute. Allows you to create a wide range of items with a wide range of attributes that weren't conceived when you wrote the domain object.

=head3 name

The attribute name.

=head3 default

The default value. Defaults to undef, which is bad because null searches are slow.

=head3 type

Valid types are 'Str', 'Int', and 'DateTime'. Defaults to 'Str'.

=cut

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

=head2 BUILD ( )

Generates the relationship methods and attribute methods on object construction. See L<Moose> for details.

=cut

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

=head2 copy ( [ id ] ) 

Creates a duplicate of this object, inserts it into the database, and returns a reference to it.

=head3 id

If you want to assign a specific id to the copy, then you can do it with this parameter.

=cut

sub copy {
    my ($self, $id) = @_;
    my %properties;
    foreach my $name (keys %{$self->attributes}) {
        $properties{$name} = $self->$name;
    }
    my $new = $self->new(domain => $self->domain, attributes => \%properties, id=>$id);
    $new->put;
    return $new;
}

#--------------------------------------------------------

=head2 delete

Removes this item from the database.

=cut

sub delete {
    my ($self) = @_;
    my $domain = $self->domain;
    $domain->simpledb->send_request('DeleteAttributes', {ItemName => $self->id, DomainName=>$domain->name});
}

#--------------------------------------------------------

=head2 delete_attribute

Removes a specific attribute from this item in the database. Great in conjunction with add_attribute().

=cut

sub delete_attribute {
    my ($self, $name) = @_;
    my $attributes = $self->attributes;
    delete $attributes->{$name};
    $self->attributes($attributes);
    my $domain = $self->domain;
    $domain->simpledb->send_request('DeleteAttributes', { ItemName => $self->id, DomainName => $domain->name, 'Attribute.0.Name' => $name } );
}

#--------------------------------------------------------

=head2 generate_uuid ( )

Class method. Generates a unique UUID that can be used as a unique id for new items.

=cut 

sub generate_uuid {
    return create_UUID_as_string(UUID_V4);
}

#--------------------------------------------------------

=head2 put ( )

Inserts/updates the current attributes of this Item object to the database.

=cut

sub put {
    my ($self) = @_;
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


=head1 AUTHOR

JT Smith <jt_at_plainblack_com>

I have to give credit where credit is due: SimpleDB::Class is heavily inspired by L<DBIx::Class> by Matt Trout (and others), and the Amazon::SimpleDB class distributed by Amazon itself (not to be confused with Amazon::SimpleDB written by Timothy Appnel).

=head1 LEGAL

SimpleDB::Class is Copyright 2009 Plain Black Corporation and is licensed under the same terms as Perl itself.

=cut

1;
