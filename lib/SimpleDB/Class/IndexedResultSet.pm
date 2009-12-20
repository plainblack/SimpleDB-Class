package SimpleDB::Class::IndexedResultSet;

=head1 NAME

SimpleDB::Class::IndexedResultSet - An iterator of items indexed in a domain item.

=head1 DESCRIPTION

This class is an iterator to walk to the items passed back from a list of item ids.

=head1 METHODS

The following methods are available from this class.

=cut

use Moose;

#--------------------------------------------------------

=head2 new ( params )

Constructor.

=head3 params

A hash.

=head4 domain

Required. A L<SimpleDB::Class::Domain> object.

=head4 ids

An array reference containing ids in the result set.

=cut

#--------------------------------------------------------

=head2 domain ( )

Returns the domain passed into the constructor.

=cut

has domain => (
    is          => 'ro',
    required    => 1,
);

#--------------------------------------------------------

=head2 ids ( )

Returns the array reference of ids passed into the constructor.

=cut

has ids => (
    is          => 'rw',
    isa         => 'ArrayRef',
    default     => sub {[]},
    lazy        => 1,
);

#--------------------------------------------------------

=head2 next () 

Returns the next result in the result set. 

=cut

sub next {
    my ($self) = @_;

    # iterate
    my $ids = $self->ids;
    my $id = shift $ids;
    return undef unless defined $id;
    $self->ids($ids);

    # make the item object
    return $self->domain->find($id);
}

=head1 LEGAL

SimpleDB::Class is Copyright 2009 Plain Black Corporation (L<http://www.plainblack.com/>) and is licensed under the same terms as Perl itself.

=cut

no Moose;
__PACKAGE__->meta->make_immutable;
