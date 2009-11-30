package Foo::Child;

use Moose;
extends 'SimpleDB::Class::Domain';

__PACKAGE__->set_name('foo_child');
__PACKAGE__->add_attributes(qw(domainId));
__PACKAGE__->belongs_to('domain', 'Foo::Domain', 'domainId');

1;

