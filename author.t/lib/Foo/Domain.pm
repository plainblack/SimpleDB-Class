package Foo::Domain;

use Moose;
extends 'SimpleDB::Class::Domain';

__PACKAGE__->set_name('foo_domain');
__PACKAGE__->add_attributes(
    color       =>{isa=>'Str'}, 
    size        =>{isa=>'Str'}, 
    parentId    =>{isa=>'Str'}, 
    quantity    =>{isa=>'Int'},
    start_date  =>{isa=>'DateTime'},
    );
__PACKAGE__->has_many('children', 'Foo::Child', 'domainId');
__PACKAGE__->belongs_to('parent', 'Foo::Parent', 'parentId');

1;

