use Test::More tests => 18;
use Test::Deep;
use lib ('../lib', 'lib');


my $access = $ENV{SIMPLEDB_ACCESS_KEY};
my $secret = $ENV{SIMPLEDB_SECRET_KEY};

unless (defined $access && defined $secret) {
    die "You need to set environment variables SIMPLEDB_ACCESS_KEY and SIMPLEDB_SECRET_KEY to run these tests.";
}

use Foo;

my $foo = Foo->new(secret_key=>$secret, access_key=>$access, cache_servers=>[{host=>'127.0.0.1', port=>11211}]);
$foo->cache->flush;
my $domain = $foo->domain('foo_domain');
isa_ok($domain,'SimpleDB::Class::Domain');
isa_ok($domain->simpledb,'SimpleDB::Class');

my $parent = $foo->domain('foo_parent');
ok($parent->create, 'create a domain');
ok(grep({$_ eq 'foo_parent'} @{$foo->list_domains}), 'got created domain');
is($parent->count, 0, 'should be 0 items');
$parent->insert({title=>'One'},'one');
$parent->insert({title=>'Two'},'two');
sleep 1; # it's eventually consistent, so we have to wait a bit to make sure it's consistent
is($parent->count, 2, 'should be 2 items');

$domain->create;
ok($domain->insert({color=>'red',size=>'large',parentId=>'one'}, 'largered'), 'adding item with id');
ok($domain->insert({color=>'blue',size=>'small',parentId=>'two'}), 'adding item without id');
is($domain->find('largered')->size, 'large', 'find() works');

my $x = $domain->insert({color=>'orange',size=>'large',parentId=>'one'});
isa_ok($x, 'Foo::Domain');
cmp_deeply($x->to_hashref, {color=>'orange',size=>'large',parentId=>'one', start_date=>undef, quantity=>undef}, 'to_hashref()');
$domain->insert({color=>'green',size=>'small',parentId=>'two'});
$domain->insert({color=>'black',size=>'huge',parentId=>'one'});
my $foos = $domain->search({size=>'small'});
isa_ok($foos, 'SimpleDB::Class::ResultSet');
isa_ok($foos->next, 'Foo::Domain');
is($foos->next->size, 'small', 'fetched an item from the result set');

my $child = $foo->domain('foo_child');
$child->create;
$child->insert({domainId=>'largered'});

is($domain->find('largered')->parent->title, 'One', 'belongs_to works');
is($domain->find('largered')->children->next->domainId, 'largered', 'has_many works');

ok($domain->delete,'deleting domain');
$parent->delete;
$child->delete;
ok(!grep({$_ eq 'foo_domain'} @{$foo->list_domains}), 'domain deleted');


