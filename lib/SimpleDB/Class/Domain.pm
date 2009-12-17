package SimpleDB::Class::Domain;

=head1 NAME

SimpleDB::Class::Domain - A schematic representation of a SimpleDB domain.

=head1 DESCRIPTION

A subclass of this class is created for each domain in SimpleDB with it's name, attributes, and relationships.

=head1 METHODS

The following methods are available from this class.

=cut

use Moose;
use SimpleDB::Class::Item;
use SimpleDB::Class::SQL;
use SimpleDB::Class::ResultSet;
use SimpleDB::Class::Exception;


#--------------------------------------------------------

=head2 new ( params ) 

Constructor. Normally you should never call this method yourself, instead use the domain() method in L<SimpleDB::Class>.

=head3 params

A hash containing the parameters needed to construct this object.

=head4 simpledb

Required. A reference to a L<SimpleDB::Class> object.

=head4 name

Required. The SimpleDB domain name associated with this class.

=cut


#--------------------------------------------------------

=head2 set_name ( name )

Class method. Used to set the SimpleDB domain name associated with a sublcass.

=head3 name

The domain name to set.

=cut

sub set_name {
    my ($class, $name) = @_;
    SimpleDB::Class->_add_domain($name => $class->new(name=>$name));
}

#--------------------------------------------------------

=head2 name ( )

Returns the name set in the constructor.

=cut

has 'name' => (
    is          => 'ro',
    required    => 1,
);

#--------------------------------------------------------

=head2 simpledb ( )

Returns the L<SimpleDB::Class> object set in the constructor.

=cut

has 'simpledb' => (
    is          => 'rw',
);

#--------------------------------------------------------

=head2 attributes ( )

Returns the hashref of attributes set by the add_attributes() method.

=cut

has 'attributes' => (
    is      => 'rw',
    isa     => 'HashRef',
    default => sub{{}},
);

#--------------------------------------------------------

=head2 parents ( )

Returns the hashref of parents set by the belongs_to() method.

=cut

has 'parents' => (
    is      => 'rw',
    isa     => 'HashRef',
    default => sub{{}},
);

#--------------------------------------------------------

=head2 children ( )

Returns the hashref of children set by the has_many() method.

=cut

has 'children' => (
    is      => 'rw',
    isa     => 'HashRef',
    default => sub{{}},
);

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
    my $self = SimpleDB::Class->determine_domain_instance($class);
    my $parents = $self->parents;
    $parents->{$name} = [$classname, $attribute];
    $self->parents($parents);
};

#--------------------------------------------------------

=head2 has_many ( method, class, attribute )

Class method. Sets up a 1:N relationship between this class and a child class.

=head3 method

The name of the method in this class you wish to use to access the relationship with the child class.

=head3 class

The class name of the class you're creating the child relationship with.

=head3 attribute

The attribute in the child class that represents this class' id.

=cut

sub has_many {
    my ($class, $name, $classname, $attribute) = @_;
    my $self = SimpleDB::Class->determine_domain_instance($class);
    my $children = $self->children;
    $children->{$name} = [$classname, $attribute];
    $self->children($children);
};

#--------------------------------------------------------

=head2 add_attributes ( list )

Class method. Adds more attributes to this class.

=head3 list

A hashref that holds a list of attributes and their properties (a hashref itself). Example: title => { isa => 'Str', default => 'Untitled' }

=head4 attribute

The attribute name is key in the hashref.

=head4 isa

The type of data represented by this attribute. Defaults to 'Str' if left out. Options are 'Str', 'Int', and 'DateTime'.

=head4 default

The default value for this attribute. This should be specified even if it is 'None' or 'Undefined' or 'Null', because actuall null queries are slow in SimpleDB.

=cut

sub add_attributes {
    my ($class, %new_attributes) = @_;
    my $self = SimpleDB::Class->determine_domain_instance($class);
    my %attributes = (%{$self->attributes}, %new_attributes);
    $self->attributes(\%attributes);
    return \%attributes;
}

#--------------------------------------------------------

=head2 create 

Creates this domain in the SimpleDB.

=cut

sub create {
    my ($self) = @_;
    $self->simpledb->send_request('CreateDomain', {
        DomainName => $self->name,
    });
}

#--------------------------------------------------------

=head2 delete

Deletes this domain from the SimpleDB.

=cut

sub delete {
    my ($self) = @_;
    $self->simpledb->send_request('DeleteDomain', {
        DomainName => $self->name,
    });
}

#--------------------------------------------------------

=head2 find ( id )

Retrieves an item from the SimpleDB by ID and then returns a L<SimpleDB::Class::Item> object.

=head3 id

The unique identifier (called ItemName in AWS documentation) of the item to retrieve.

=cut

sub find {
    my ($self, $id) = @_;
    my $cache = $self->simpledb->cache;
    my $attributes = eval{$cache->get($self->name, $id)};
    my $e;
    if (SimpleDB::Class::Exception::ObjectNotFound->caught) {
        my $result = $self->simpledb->send_request('GetAttributes', {
            ItemName    => $id,
            DomainName  => $self->name,
        });
        my $item = SimpleDB::Class::ResultSet->new(domain=>$self)->handle_item($id, $result->{GetAttributesResult}{Attribute});
        $cache->set($self->name, $id, $item->to_hashref);
        return $item;
    }
    elsif (my $e = SimpleDB::Class::Exception->caught) {
        warn $e->error;
        return $e->rethrow;
    }
    elsif (defined $attributes) {
        return SimpleDB::Class::Item->new(id=>$id, domain=>$self, attributes=>$attributes);
    }
    else {
        SimpleDB::Class::Exception->throw(error=>"An undefined error occured while fetching the item.");
    }
}

#--------------------------------------------------------

=head2 insert ( attributes, [ id ] ) 

Adds a new item to this domain.

=head3 attributes

A hash reference of name value pairs to insert as attributes into this item.

=head3 id

Optionally specify a unqiue id for this item.

=cut

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

=head2 count ( [ where ] ) 

Returns an integer indicating how many items are in this domain.

=head3 where

A where clause as defined in L<SimpleDB::Class::SQL> if you want to count only a certain number of items in the domain.

=cut

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

=head2 search ( where )

Returns a L<SimpleDB::Class::ResultSet> object.

=head3 where

A where clause as defined by L<SimpleDB::Class::SQL>.

=cut

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
