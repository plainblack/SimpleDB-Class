package Foo::Domain;

use Moose;
extends 'SimpleDB::Class::Domain';

__PACKAGE__->name('foo_domain');
__PACKAGE__->add_attributes(qw(color size));

1;

