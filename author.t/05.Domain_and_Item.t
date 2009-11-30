use Test::More tests => 13;
use lib ('../lib', 'lib');


my $access = $ENV{SIMPLEDB_ACCESS_KEY};
my $secret = $ENV{SIMPLEDB_SECRET_KEY};

unless (defined $access && defined $secret) {
    die "You need to set environment variables SIMPLEDB_ACCESS_KEY and SIMPLEDB_SECRET_KEY to run these tests.";
}


use Foo;
use Foo::Domain;

my $foo = Foo->new(secret_key=>$secret, access_key=>$access);
my $domain = $foo->domain('foo_domain');
isa_ok($domain,'Foo::Domain');
ok($domain->create, 'create a domain');
ok(grep({$_ eq 'foo_domain'} @{$foo->list_domains}), 'got created domain');
is($domain->count, 0, 'should be 0 items');
ok($domain->insert({color=>'red',size=>'large'}, 'largered'), 'adding item with id');
ok($domain->insert({color=>'blue',size=>'small'}), 'adding item without id');
is($domain->count, 2, 'should be 2 items');
is($domain->find('largered')->size, 'large', 'find() works');

$domain->insert({color=>'orange',size=>'large'});
$domain->insert({color=>'green',size=>'small'});
$domain->insert({color=>'black',size=>'huge'});
my $foos = $domain->search({size=>'small'});
isa_ok($foos, 'SimpleDB::Class::ResultSet');
isa_ok($foos->next, 'SimpleDB::Class::Item');
is($foos->next->size, 'small', 'fetched an item from the result set');
ok($domain->delete,'deleting domain');
ok(!grep({$_ eq 'foo_domain'} @{$foo->list_domains}), 'domain deleted');


