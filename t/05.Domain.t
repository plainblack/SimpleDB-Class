use Test::More tests => 3;
use Test::Deep;
use lib '../lib';

use SimpleDB::Class;
use_ok( 'SimpleDB::Class::Domain' );

my @attributes = ('foo', 'bar', 'xxx');

SimpleDB::Class::Domain->set_name('test');
my $db = SimpleDB::Class->new(access_key=>'access', secret_key=>'secret');

my $domain = $db->domain('SimpleDB::Class::Domain');
is($domain->name, 'test', 'domain name assignment works');

SimpleDB::Class::Domain->add_attributes(@attributes);
cmp_deeply(
    $domain->attributes,
    \@attributes,
    'attributes work'
);


# everything else requires a connection
