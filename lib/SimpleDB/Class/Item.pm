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
use Sub::Name ();

#--------------------------------------------------------
sub _install_sub {
    my ($name, $sub) = @_;
    no strict 'refs';
    *{$name} = Sub::Name::subname($name, $sub);
}

#--------------------------------------------------------

=head2 set_domain_name ( name )

Class method. Used to set the SimpleDB domain name associated with a sublcass.

=head3 name

The domain name to set.

=head2 domain_name ( )

After set_domain_name() has been called, there will be a domain_name method, that will return the value of the domain name.

=cut

sub set_domain_name {
    my ($class, $name) = @_;
    # inject domain_name sub
    _install_sub($class.'::domain_name', sub { return $name });
    # register the name and class with the schema
    my $names = SimpleDB::Class->domain_names;
    $names->{$name} = $class; 
    SimpleDB::Class->domain_names($names);
}

#--------------------------------------------------------

=head2 add_attributes ( list )

Class method. Adds more attributes to this class. B<NOTE:> This will add a method to your class which can be used as an accessor/mutator. Therefore make sure to avoid method name conflicts with this class.

=head3 list

A hashref that holds a list of attributes and their properties (a hashref itself). Example: title => { isa => 'Str', default => 'Untitled' }

=head4 attribute

The attribute name is key in the hashref.

=head4 isa

The type of data represented by this attribute. Defaults to 'Str' if left out. Options are 'Str', 'Int', 'HashRef', and 'DateTime'.

=head4 default

The default value for this attribute. This should be specified even if it is 'None' or 'Undefined' or 'Null', because actuall null queries are slow in SimpleDB.

=head4 trigger

A sub reference that will be called like a method (has reference to $self), and is also passed the new and old values of this attribute. Works just like a L<Moose> trigger. See also L<Moose::Manual::Attributes/"Triggers">.

=cut

sub add_attributes {
    my ($class, %attributes) = @_;
    foreach my $name (keys %attributes) {
        # i wish i could actually use Moose attributes here, but unfortunately
        # Moose calls 'has' on __PACKAGE__ rather than $class, so it would insert
        # the attributes into this class rather than each subclass
        my $trigger = $attributes{$name}{trigger};
        my $accessor = sub { 
                my ($self, $new) = @_; 
                my $attr = $self->attribute_data;
                if (defined $new) {
                    my $has_old = exists $attr->{name};
                    my $old = $attr->{name};
                    $attr->{$name} = $new;
                    $self->attribute_data($attr);
                    if (defined $trigger) {
                        my @params = ($self, $new);
                        if ($has_old) {
                            push @params, $old;
                        }
                        $trigger->(@params);
                    }
                }
                return $attr->{$name};
        };
        _install_sub($class.'::'.$name, $accessor);
    }
    my %new = (%{$class->attributes}, %attributes);
    _install_sub($class.'::attributes', sub { return \%new; });
}

has attribute_data => (
    is      => 'rw',
    default => sub {{}},
);

#--------------------------------------------------------

=head2 has_many ( method, class, attribute )

Class method. Sets up a 1:N relationship between this class and a child class.

WARNING: With this method you need to be aware that SimpleDB is eventually consistent. See L<SimpleDB::Class/"Eventual Consistency"> for details.

=head3 method

The name of the method in this class you wish to use to access the relationship with the child class.

=head3 class

The class name of the class you're creating the child relationship with.

=head3 attribute

The attribute in the child class that represents this class' id.

=cut

sub has_many {
    my ($class, $name, $classname, $attribute) = @_;
    _install_sub($class.'::'.$name, sub { my $self = shift; return $self->simpledb->domain($classname)->search({$attribute => $self->id}); });
}

#--------------------------------------------------------

=head2 belongs_to ( method, class, attribute )

Class method. Adds a 1:N relationship between another class and this one.

=head3 method

The method name to create to represent this relationship in this class.

=head3 class

The class name of the parent class you're relating this class to.

=head3 attribute

The attribute in this class' attribute list that represents the id of the parent class.

=cut

sub belongs_to {
    my ($class, $name, $classname, $attribute) = @_;
    _install_sub($class.'::'.$name, sub { my $self = shift; return $self->simpledb->domain($classname)->find($self->$attribute); });
};

#--------------------------------------------------------

=head2 attributes ( )

Class method. Returns the hashref of attributes set by the add_attributes() method.

=cut
sub attributes { return {} };


#--------------------------------------------------------

=head2 recast_using ( attribute_name ) 

Class method. Sets an attribue name to use to recast this object as another class. This allows you to pull multiple object types from the same domain. If the attribute is defined when reading the information from SimpleDB, the object will be cast as the classname returned, rather than the classname associated with the domain. The new class must be a subclass of the class associated with the domain, because you cannot C<set_domain_name> for the same domain twice, or you will break SimpleDB::Class.

=head3 attribute_name

The name of an attribute defined by C<add_attributes>. 

=cut

sub recast_using {
    my ($class, $attribute_name) = @_;
    _install_sub($class.'::_castor_attribute', sub { return $attribute_name });
}

sub _castor_attribute {
    return undef;
}

#--------------------------------------------------------

=head2 update ( attributes ) 

Update a bunch of attributes all at once. Returns a reference to L<$self> so it can be chained into other methods.

=head3 attributes

A hash reference containing attribute names and values.

=cut

sub update {
    my ($self, $attributes) = @_;
    my $registered_attributes = $self->attributes;
    foreach my $attribute (keys %{$attributes}) {
        # add unknown attributes
        if (!exists $registered_attributes->{$attribute}) {
           $self->add_attributes($attribute => { isa => 'Str' }); 
        }

        # update attribute value
        $self->$attribute($attributes->{$attribute});
    }
    return $self;
}


#--------------------------------------------------------

=head2 new ( params )

Constructor.

=head3 params

A hash.

=head4 id

The unique identifier (ItemName) of the item represented by this class. If you don't pass this in, an item ID will be generated for you automatically.

=head4 simpledb 

Required. A L<SimpleDB::Class> object.

=head4 attributes

Required. A hashref containing the names and values of the attributes associated with this item.

=head2 {attribute} ( [ value ] )

For each attribute passed into the constructor, an accessor / mutator will be added to this class allowing you to get or set it's current value.

=head3

If specified, sets the current value of the attribute. Note, that this doesn't update the database, for that you must call the put() method.

=cut

#--------------------------------------------------------

=head2 simpledb ( )

Returns the simpledb passed into the constructor.

=cut

has simpledb => (
    is          => 'ro',
    required    => 1,
);

#--------------------------------------------------------

=head2 id ( )

Returns the unique id of this item. B<Note:> Even though the primary key C<ItemName> (or C<id> as we call it) is a special property of an item, an C<id> attribute is also automatically added to every item when C<put> is called, which contains the same value as the C<ItemName>. This is so you can perform searches based upon the id, which is not something you can normally do with a C<Select> in SimpleDB.

=cut

has id => (
    is          => 'ro',
    builder     => 'generate_uuid',
    lazy        => 1,
);

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
    my $new = $self->new(simpledb => $self->simpledb, attributes => \%properties, id=>$id);
    $new->put;
    return $new;
}

#--------------------------------------------------------

=head2 delete

Removes this item from the database.

=cut

sub delete {
    my ($self) = @_;
    my $simpledb = $self->simpledb;
    eval{$simpledb->cache->delete($self->domain_name, $self->id)};
    $simpledb->http->send_request('DeleteAttributes', {ItemName => $self->id, DomainName=>$self->domain_name});
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
    my $simpledb = $self->simpledb;
    eval{$simpledb->cache->set($self->domain_name, $self->id, $attributes)};
    $simpledb->http->send_request('DeleteAttributes', { ItemName => $self->id, DomainName => $self->domain_name, 'Attribute.0.Name' => $name } );
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

Inserts/updates the current attributes of this Item object to the database.  Returns a reference to L<$self> so it can be chained into other methods.

=cut

sub put {
    my ($self) = @_;

    # build the parameter list
    my $params = {ItemName => $self->id, DomainName=>$self->domain_name};
    my $i = 0;
    my $select = SimpleDB::Class::SQL->new(item_class=>ref($self)); 
    my $attributes = $self->to_hashref;
    foreach my $name (keys %{$attributes}) {
        my $values = $attributes->{$name};
        next unless defined $values; # don't store null values
        unless ($values eq 'ARRAY') {
            $values = [$values];
        }
        foreach my $value (@{$values}) {
            $value = $select->format_value($name, $value, 1);
            $params->{'Attribute.'.$i.'.Name'} = $name;
            $params->{'Attribute.'.$i.'.Value'} = $value;
            $params->{'Attribute.'.$i.'.Replace'} = 'true';
            $i++;
        }
    }

    # add the id, so we can search on it
    $params->{'Attribute.'.$i.'.Name'} = 'id';
    $params->{'Attribute.'.$i.'.Replace'} = 'true';
    $params->{'Attribute.'.$i.'.Value'} = $self->id;

    # push changes
    my $simpledb = $self->simpledb;
    eval{$simpledb->cache->set($self->domain_name, $self->id, $attributes)};
    $simpledb->http->send_request('PutAttributes', $params);
    return $self;
}

#--------------------------------------------------------

=head2 to_hashref ( )

Returns a hash reference of the attributes asscoiated with this item.

=cut

sub to_hashref {
    my ($self) = @_;
    my %properties;
    foreach my $attribute (keys %{$self->attributes}) {                                                
        $properties{$attribute} = $self->$attribute;
    }
    return \%properties;
}

=head1 LEGAL

SimpleDB::Class is Copyright 2009 Plain Black Corporation (L<http://www.plainblack.com/>) and is licensed under the same terms as Perl itself.

=cut

1;
