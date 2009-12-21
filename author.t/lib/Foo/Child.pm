package Foo::Child;

use Moose;
extends 'SimpleDB::Class::Item';

__PACKAGE__->set_domain_name('foo_child');
__PACKAGE__->add_attributes(domainId=>{isa=>'Str'});
__PACKAGE__->belongs_to('domain', 'Foo::Domain', 'domainId');

1;

