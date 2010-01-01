package SimpleDB::Class::Role::Itemized;

use Moose::Role;

requires 'item_class';

=head1 NAME

SimpleDB::Class::Role::Itemized - Provides utility methods to classes that need to instantiate items.

=head1 SYNOPSIS

 my $class = $self->determine_item_class(\%attributes);

 my $item = $self->instantiate_item(\%attributes, $id);

=head1 DESCRIPTION

This is a L<Moose::Role> that provides utility methods for instantiating L<SimpleDB::Class::Item>s.

=head1 METHODS

The following methods are available from this role.

=cut

#--------------------------------------------------------

=head2 instantiate_item ( attributes, [ id ] )

Instantiates an item based upon it's proper classname and then calls C<update> to populate it's attributes with data.

=head3 attributes

A hash reference of attribute data.

=head3 id

An optional id to instantiate the item with.

=cut

sub instantiate_item {
    my ($self, $attributes, $id) = @_;
    my %params = (simpledb=>$self->simpledb);
    if (defined $id && $id ne '') {
        $params{id} = $id;
    }
    return $self->determine_item_class($attributes)->new(%params)->update($attributes);
}

#--------------------------------------------------------

=head2 determine_item_class ( attributes ) 

Given an attribute list we can determine if an item needs to be recast as a different class.

=head3 attributes

A hash ref of attributes.

=cut

sub determine_item_class {
    my ($self, $attributes) = @_;
    my $class = $self->item_class;
    my $castor = $class->_castor_attribute;
    if ($castor) {
        my $reclass = $attributes->{$castor};
        if ($reclass) {
            return $reclass;
        }
    }
    return $class;
}

=head1 LEGAL

SimpleDB::Class is Copyright 2009 Plain Black Corporation (L<http://www.plainblack.com/>) and is licensed under the same terms as Perl itself.

=cut


1;
