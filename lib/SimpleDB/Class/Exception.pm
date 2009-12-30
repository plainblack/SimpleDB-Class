package SimpleDB::Class::Exception;

=head1 NAME

SimpleDB::Class::Exception - Exceptions thrown by SimpleDB::Class.

=head1 DESCRIPTION

A submclass of L<Exception::Class> that defines expcetions to be thrown through-out L<SimpleDB::Class> ojbects.

=head1 EXCEPTIONS

The following exceptions are available from this class.

=head2 SimpleDB::Class::Exception

A general error. Isa Exception::Class.

=head2 SimpleDB::Class::Exception::OverrideMe

Used when creating abstract methods. Isa SimpleDB::Class::Exception.

=head2 SimpleDB::Class::Exception::ObjectNotFound

Thrown when a request object is not found.

=head3 id

The id of the requested object.

=head2 SimpleDB::Class::Exception::InvalidParam

Thrown when a parameter isn't passed when it should have been, or if it's left undefined. Isa SimpleDB::Class::Exception::ObjectNotFound.

=head2 SimpleDB::Class::Exception::InvalidObject

Thrown when a request object is found, but is corrupt. Isa SimpleDB::Class::Exception::ObjectNotFound.

=head2 SimpleDB::Class::Exception::Connection

Thrown when exceptions occur connecting to the SimpleDB database at Amazon, or the memcached server. Isa SimpleDB::Class::Exception.

=head3 status_code

The HTTP status code returned.

=head2 SimpleDB::Class::Exception::Response

Isa SimpleDB::Class::Exception::Connection. Thrown when SimpleDB reports an error.

=head3 error_code

The error code returned from SimpleDB.

=head3 request_id

The request id as returned from SimpleDB.

=head3 box_usage

The storage usage in your SimpleDB.

=head3 response

The L<HTTP::Response> object as retrieved from the SimpleDB request.

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
    'SimpleDB::Class::Exception::InvalidParam' => {
        isa             => 'SimpleDB::Class::Exception',
        description     => 'This method should be overridden by subclasses.',
        fields          => ['name', 'value'],
        },
    'SimpleDB::Class::Exception::ObjectNotFound' => {
        isa             => 'SimpleDB::Class::Exception',
        description     => "The object you were trying to retrieve does not exist.",
        fields          => ['id'],
        },
    'SimpleDB::Class::Exception::InvalidObject' => {
        isa             => 'SimpleDB::Class::Exception::ObjectNotFound',
        description     => "The object you were trying to retrieve does not exist.",
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

=head1 LEGAL

SimpleDB::Class is Copyright 2009 Plain Black Corporation (L<http://www.plainblack.com/>) and is licensed under the same terms as Perl itself.

=cut

1;
