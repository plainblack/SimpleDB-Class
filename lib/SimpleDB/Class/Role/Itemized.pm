package SimpleDB::Class::Role::Itemized;

use Moose::Role;

requires 'item_class';

#--------------------------------------------------------

=head2 instantiate_item ( attributes, [ id ] )

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



1;
