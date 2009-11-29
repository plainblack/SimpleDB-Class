use Test::More tests => 3;
use Test::Deep;
use lib '../lib';

use SimpleDB::Class;
use_ok( 'SimpleDB::Class::Domain' );

my @attributes = ('foo', 'bar', 'xxx');

SimpleDB::Class::Domain->name('test');
is(SimpleDB::Class::Domain->name, 'test', 'domain name assignment works');

SimpleDB::Class::Domain->add_attributes(@attributes);
cmp_deeply(
    SimpleDB::Class::Domain->attributes,
    \@attributes,
    'attributes work'
);


# everything else requires a connection
