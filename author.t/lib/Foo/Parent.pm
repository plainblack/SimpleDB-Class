package Foo::Parent;

use Moose;
extends 'SimpleDB::Class::Item';

__PACKAGE__->set_domain_name('foo_parent');
__PACKAGE__->add_attributes(title=>{isa=>'Str'});
__PACKAGE__->has_many('domains', 'Foo::Domain', 'parentId', 'parent');

1;

