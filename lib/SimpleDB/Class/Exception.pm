package SimpleDB::Class::Exception;

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

1;
