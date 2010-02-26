use Test::More tests => 35;
use Test::Deep;
use lib ('../lib', 'lib');
$|=1;

my $access = $ENV{SIMPLEDB_ACCESS_KEY};
my $secret = $ENV{SIMPLEDB_SECRET_KEY};

unless (defined $access && defined $secret) {
    die "You need to set environment variables SIMPLEDB_ACCESS_KEY and SIMPLEDB_SECRET_KEY to run these tests.";
}

use Foo;
my %params = (secret_key=>$secret, access_key=>$access, cache_servers=>[{host=>'127.0.0.1', port=>11211}]);
if ($ARGV[0]) {
    $params{domain_prefix} = $ARGV[0];
}
my $foo = Foo->new(%params);
$foo->cache->flush;
my $domain = $foo->domain('foo_domain');
isa_ok($domain,'SimpleDB::Class::Domain');
isa_ok($domain->simpledb,'SimpleDB::Class');

my $parent = $foo->domain('foo_parent');
ok($parent->create, 'create a domain');
my $domain_expected = 'foo_parent';
if ($ARGV[0]) {
    $domain_expected = $ARGV[0].$domain_expected;
}
ok(grep({$_ eq $domain_expected} @{$foo->list_domains}), 'got created domain');
is($parent->count, 0, 'should be 0 items');
$parent->insert({title=>'One'},'one');
$parent->insert({title=>'Two'},'two');
sleep 1; # it's eventually consistent, so we have to wait a bit to make sure it's consistent
is($parent->count, 2, 'should be 2 items');

$domain->create;
ok($domain->insert({color=>'red',size=>'large',parentId=>'one',quantity=>5}, 'largered'), 'adding item with id');
ok($domain->insert({color=>'blue',size=>'small',parentId=>'two',quantity=>1}), 'adding item without id');
is($domain->find('largered')->size, 'large', 'find() works');

my $x = $domain->insert({color=>'orange',size=>'large',parentId=>'one',properties=>{this=>'that'},quantity=>3});
isa_ok($x, 'Foo::Domain');
cmp_deeply($x->to_hashref, {properties=>{this=>'that'}, color=>'orange',size=>'large',size_formatted=>'Large',parentId=>'one', start_date=>undef, quantity=>3}, 'to_hashref()');
$domain->insert({color=>'green',size=>'small',parentId=>'two',quantity=>11});
$domain->insert({color=>'black',size=>'huge',parentId=>'one',quantity=>2});
sleep 1;
is($domain->max('quantity'), 11, 'max');
is($domain->min('quantity'), 1, 'min');
is($domain->max('quantity',{parentId=>'one'}), 5, 'max with clause');
is($domain->min('quantity',{parentId=>'one'}), 2, 'min with clause');

my $foos = $domain->search({size=>'small'});
isa_ok($foos, 'SimpleDB::Class::ResultSet');
isa_ok($foos->next, 'Foo::Domain');
my $a_domain = $foos->next;
ok($a_domain->can('size'), 'attribute methods created');
ok(!$a_domain->can('title'), 'other class attribute methods not created');
is($a_domain->size, 'small', 'fetched an item from the result set');
$foos = $domain->search({size=>'small'});
is($foos->count, 2, 'counting items in a result set');
$foos = $domain->search({size=>'small'});
is($foos->count({color=>'green'}), 1, 'counting subset of items in a result set');

my $children = $foo->domain('foo_child');
$children->create;
my $child = $children->insert({domainId=>'largered'});
isa_ok($child, 'Foo::Child');
my $subchild = $children->insert({domainId=>'largered', class=>'Foo::SubChild'});
isa_ok($subchild, 'Foo::SubChild');

is($domain->find('largered')->parent->title, 'One', 'belongs_to works');
is($domain->find('largered')->children->next->domainId, 'largered', 'has_many works');

my $j = $domain->insert({start_date=>DateTime->new(year=>2000, month=>5, day=>5, hour=>5, minute=>5, second=>5), color=>'orange',size=>'large',parentId=>'one',properties=>{this=>'that'},quantity=>3});
my $j1 = $domain->find($j->id);
cmp_ok($j->start_date, '==', $j1->start_date, 'dates in are dates out');
is($j->start_date->year, 2000, 'year');
is($j->start_date->month, 5, 'month');
is($j->start_date->day, 5, 'day');
is($j->start_date->hour, 5, 'hour');
is($j->start_date->minute, 5, 'minute');
is($j->start_date->second, 5, 'second');

ok($domain->delete,'deleting domain');
$parent->delete;
$children->delete;
ok(!grep({$_ eq 'foo_domain'} @{$foo->list_domains}), 'domain deleted');


