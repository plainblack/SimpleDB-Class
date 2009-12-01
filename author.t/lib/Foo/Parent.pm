package Foo::Parent;

use Moose;
extends 'SimpleDB::Class::Domain';

__PACKAGE__->set_name('foo_parent');
__PACKAGE__->add_attributes(title=>{isa=>'Str'});
__PACKAGE__->has_many('domains', 'Foo::Domain', 'parentId');

1;

