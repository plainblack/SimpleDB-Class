package Foo::Domain;

use Moose;
extends 'SimpleDB::Class::Domain';

__PACKAGE__->set_name('foo_domain');
__PACKAGE__->add_attributes(qw(color size parentId));
__PACKAGE__->has_many('children', 'Foo::Child', 'domainId');
__PACKAGE__->belongs_to('parent', 'Foo::Parent', 'parentId');

1;

