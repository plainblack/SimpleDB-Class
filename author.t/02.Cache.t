use Test::More tests => 7;
use Tie::IxHash;
use lib ('../lib', 'lib');

my $a = {foo=>'A'};
my $b = {foo=>'B'};

use_ok('SimpleDB::Class::Cache');
my $cache = SimpleDB::Class::Cache->new(servers=>[{host=>'127.0.0.1',port=>11211}]);
isa_ok($cache, 'SimpleDB::Class::Cache');
$cache->set("a",$a);
is($cache->get("a")->{foo}, "A", "set/get");
$cache->set("b", $b);
my ($a1, $b1) = @{$cache->mget(["a","b"])};
is($a1->{foo}, "A", "mget first value");
is($b1->{foo}, "B", "mget second value");
$cache->delete("a");
is(eval{$cache->get("a")}, undef, 'delete');
$cache->flush;
is(eval{$cache->get("b")}, undef, 'flush');
