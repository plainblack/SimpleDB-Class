use Test::More tests => 17;
use Test::Deep;
use lib ('../lib', 'lib');


my $access = $ENV{SIMPLEDB_ACCESS_KEY};
my $secret = $ENV{SIMPLEDB_SECRET_KEY};

unless (defined $access && defined $secret) {
    die "You need to set environment variables SIMPLEDB_ACCESS_KEY and SIMPLEDB_SECRET_KEY to run these tests.";
}


use Foo;

my $foo = Foo->new(secret_key=>$secret, access_key=>$access, cache_servers=>[{host=>'127.0.0.1', port=>11211}]);
my $domain = $foo->domain('foo_domain');
isa_ok($domain,'Foo::Domain');
isa_ok($domain->simpledb,'SimpleDB::Class');
ok($domain->create, 'create a domain');
ok(grep({$_ eq 'foo_domain'} @{$foo->list_domains}), 'got created domain');
is($domain->count, 0, 'should be 0 items');
ok($domain->insert({color=>'red',size=>'large',parentId=>'one'}, 'largered'), 'adding item with id');
ok($domain->insert({color=>'blue',size=>'small',parentId=>'two'}), 'adding item without id');
sleep 1; # it's eventually consistent, so we have to wait a bit to make sure it's consistent
is($domain->count, 2, 'should be 2 items');
is($domain->find('largered')->size, 'large', 'find() works');

my $x = $domain->insert({color=>'orange',size=>'large',parentId=>'one'});
cmp_deeply($x->to_hashref, {color=>'orange',size=>'large',parentId=>'one'}, 'to_hashref()');
$domain->insert({color=>'green',size=>'small',parentId=>'two'});
$domain->insert({color=>'black',size=>'huge',parentId=>'one'});
my $foos = $domain->search({size=>'small'});
isa_ok($foos, 'SimpleDB::Class::ResultSet');
isa_ok($foos->next, 'SimpleDB::Class::Item');
is($foos->next->size, 'small', 'fetched an item from the result set');

my $parent = $foo->domain('foo_parent');
$parent->create;
$parent->insert({title=>'One'},'one');
$parent->insert({title=>'Two'},'two');
my $child = $foo->domain('foo_child');
$child->create;
$child->insert({domainId=>'largered'});

is($domain->find('largered')->parent->title, 'One', 'belongs_to works');
is($domain->find('largered')->children->next->domainId, 'largered', 'has_many works');

ok($domain->delete,'deleting domain');
$parent->delete;
$child->delete;
ok(!grep({$_ eq 'foo_domain'} @{$foo->list_domains}), 'domain deleted');


