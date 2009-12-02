package SimpleDB::Class::Exception;

=head1 NAME



=head1 DESCRIPTION



=head1 METHODS

The following methods are available from this class.

=cut

use strict;
use Exception::Class (

    'SimpleDB::Class::Exception' => {
        description     => "A general error occured.",
        },
    'SimpleDB::Class::Exception::OverrideMe' => {
        isa             => 'SimpleDB::Class::Exception',
        description     => 'This method should be overridden by subclasses.',
        },
    'SimpleDB::Class::Exception::MethodNotFound' => {
        isa             => 'SimpleDB::Class::Exception',
        description     => q|Called a method that doesn't exist.|,
        fields          => 'method'
        },
    'SimpleDB::Class::Exception::ObjectNotFound' => {
        isa             => 'SimpleDB::Class::Exception',
        description     => "The object you were trying to retrieve does not exist.",
        fields          => ['id'],
        },
    'SimpleDB::Class::Exception::Connection' => {
        isa             => 'SimpleDB::Class::Exception',
        description     => "There was a problem establishing a connection.",
        fields          => ['status_code'],
        },
    'SimpleDB::Class::Exception::Response' => {
        isa             => 'SimpleDB::Class::Exception::Connection',
        description     => "The database reported an error.",
        fields          => ['error_code','request_id','box_usage','response'],
        },

);

=head1 AUTHOR

JT Smith <jt_at_plainblack_com>

I have to give credit where credit is due: SimpleDB::Class is heavily inspired by L<DBIx::Class> by Matt Trout (and others), and the Amazon::SimpleDB class distributed by Amazon itself (not to be confused with Amazon::SimpleDB written by Timothy Appnel).

=head1 LEGAL

SimpleDB::Class is Copyright 2009 Plain Black Corporation and is licensed under the same terms as Perl itself.

=cut

1;
