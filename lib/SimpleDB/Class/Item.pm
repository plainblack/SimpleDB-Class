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
use SimpleDB::Class::Types ':all';
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

Class method. After set_domain_name() has been called, there will be a domain_name method, that will return the value of the domain name.

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

The type of data represented by this attribute. Defaults to 'Str' if left out. Options are 'Str', 'Int', 'HashRef', and 'DateTime' for individual values, or if you want to treat the field as a multi-value then 'ArrayRefOfStr', 'ArrayRefOfInt', 'ArrayRefOfHashRef', or 'ArrayRefOfDateTime'.

=head4 default

The default value for this attribute. This should be specified even if it is 'None' or 'Undefined' or 'Null', because actuall null queries are slow in SimpleDB.

=head4 trigger

A sub reference that will be called like a method (has reference to $self), and is also passed the new and old values of this attribute. Behind the scenes is a L<Moose> trigger. See also L<Moose::Manual::Attributes/"Triggers">.

=cut

sub add_attributes {
    my ($class, %attributes) = @_;
    foreach my $name (keys %attributes) {
        my $isa = $attributes{$name}{isa} || 'Str';
        $isa = 'SimpleDB::Class::Types::Sdb'.$isa;
        my %properties = (
            is      => 'rw',
            isa     => $isa,
            coerce  => 1,
            default => $attributes{$name}{default} || undef,
            );
        if (defined $attributes{$name}{trigger}) {
            $properties{trigger} = $attributes{$name}{trigger};
        }
        $class->meta->add_attribute($name, \%properties);
    }
    my %new = (%{$class->attributes}, %attributes);
    _install_sub($class.'::attributes', sub { return \%new; });
}


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

B<Note:> The generated method will return C<undef> if the attribute specified has no value at the time it is called.

=head3 method

The method name to create to represent this relationship in this class.

=head3 class

The class name of the parent class you're relating this class to.

=head3 attribute

The attribute in this class' attribute list that represents the id of the parent class.

=cut

sub belongs_to {
    my ($class, $name, $classname, $attribute) = @_;
    my $sub = sub { 
        my $self = shift; 
        my $id = $self->$attribute;
        return undef unless ($id ne '');
        return $self->simpledb->domain($classname)->find($id); 
    };
    _install_sub($class.'::'.$name, $sub);
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

Returns the unique id of this item. B<Note:> The primary key C<ItemName> (or C<id> as we call it) is a special property of an item that doesn't exist in it's own data. So if you want to search on the id, you have to use C<itemName()> in your queries as the attribute name.

=cut

has id => (
    is          => 'ro',
    isa         => SdbStr,
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
    my %params = (simpledb => $self->simpledb);
    if (defined $id) {
        $params{id} = $id;
    }
    my $new = $self->new(\%params)->update(\%properties)->put;
    return $new;
}

#--------------------------------------------------------

=head2 delete

Removes this item from the database.

=cut

sub delete {
    my ($self) = @_;
    my $db = $self->simpledb;
    my $domain_name = $db->add_domain_prefix($self->domain_name);
    eval{$db->cache->delete($domain_name, $self->id)};
    $db->http->send_request('DeleteAttributes', {ItemName => $self->id, DomainName=>$domain_name});
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
    my $db = $self->simpledb;
    my $domain_name = $db->add_domain_prefix($self->domain_name);
    eval{$db->cache->set($domain_name, $self->id, $attributes)};
    $db->http->send_request('DeleteAttributes', { ItemName => $self->id, DomainName => $domain_name, 'Attribute.0.Name' => $name } );
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
    my $db = $self->simpledb;
    my $domain_name = $db->add_domain_prefix($self->domain_name);
    my $i = 0;
    my $attributes = $self->to_hashref;

    # build the parameter list
    my $params = {ItemName => $self->id, DomainName=>$domain_name};
    foreach my $name (keys %{$attributes}) {                                                
        my $type = $self->meta->find_attribute_by_name($name)->type_constraint;
        my $values = $self->$name;
        next unless defined $values; # don't store null values
        unless ($type =~ m/Str$/) {
            my $to_type = $type;
            $to_type =~ s/SimpleDB::Class::Types::(.*)/to_$1AsStr/;
            no strict;
            $values = $to_type->($values);
            use strict;
        }
        unless (ref $values eq 'ARRAY') {
            $values = [$values];
        }
        foreach my $value (@{$values}) {
            $params->{'Attribute.'.$i.'.Name'} = $name;
            $params->{'Attribute.'.$i.'.Value'} = $value;
            $params->{'Attribute.'.$i.'.Replace'} = 'true';
            $i++;
        }
    }

    # push changes
    eval{$db->cache->set($domain_name, $self->id, $attributes)};
    $db->http->send_request('PutAttributes', $params);
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
        next if $attribute eq 'id';
        $properties{$attribute} = $self->$attribute;
    }
    return \%properties;
}

#--------------------------------------------------------

=head2 parse_value ( name, value ) 

Class method. Returns the proper type for an attribute value in this class. So it could take a date string and turn it into a L<DateTime> object. See C<stringify_value> for the opposite.

=head3 name

The name of the attribute to parse.

=head3 value

The current stringified value to parse.

=cut

sub parse_value {
    my ($class, $name, $value) = @_;
    my $isa = 'SdbStr';
    unless ($name eq 'itemName()') {
        my $attribute = $class->meta->find_attribute_by_name($name);
        SimpleDB::Class::Exception::InvalidParam->throw(
            name    => 'name',
            value   => $name,
            error   => q{There is no attribute called '}.$name.q{'.},
            ) unless defined $attribute;
        $isa = $attribute->type_constraint;
    }
    # unpad integers
    if ($isa =~ m/Int/) {
        return to_SdbInt($value); 
    }
    # unjsonify hashrefs
    elsif ($isa =~ m/HashRef/) {
        return to_SdbHashRef($value); 
    }
    # unstringify dates
    elsif ($isa =~ m/DateTime/) {
        return to_SdbDateTime($value);
    }
    return $value;
}

#--------------------------------------------------------

=head2 stringify_value ( name, value )

Class method. Formats an attribute as a string using one of the L<SimpleDB::Class::Types> to_* functions in this class. See C<parse_value>, as this is the reverse of that.

=head3 name

The name of the attribute to format.

=head3 value

The value to format.

=cut

sub stringify_value {
    my ($class, $name, $value) = @_;
    my $isa = 'SdbStr';
    unless ($name eq 'itemName()') {
        my $attribute = $class->meta->find_attribute_by_name($name);
        SimpleDB::Class::Exception::InvalidParam->throw(
            name    => 'name',
            value   => $name,
            error   => q{There is no attribute called '}.$name.q{'.},
            ) unless defined $attribute;
        $isa = $attribute->type_constraint;
    }
    # pad integers
    if ($isa =~ m/Int/) {
        return to_SdbIntAsStr($value); 
    }
    # jsonify hashrefs
    elsif ($isa =~ m/HashRef/) {
        return to_SdbHashRefAsStr($value); 
    }
    # stringify dates
    elsif ($isa =~ m/DateTime/) {
        return to_SdbDateTimeAsStr($value);
    }
    return $value;
}

=head1 LEGAL

SimpleDB::Class is Copyright 2009-2010 Plain Black Corporation (L<http://www.plainblack.com/>) and is licensed under the same terms as Perl itself.

=cut

1;
