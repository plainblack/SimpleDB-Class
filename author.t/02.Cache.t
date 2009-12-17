use Test::More tests => 7;
use Tie::IxHash;
use lib ('../lib', 'lib');

my $a = {foo=>'A'};
my $b = {foo=>'B'};

use_ok('SimpleDB::Class::Cache');
my $cache = SimpleDB::Class::Cache->new(servers=>[{host=>'127.0.0.1',port=>11211}]);
isa_ok($cache, 'SimpleDB::Class::Cache');
$cache->set('foo',"a",$a);
is($cache->get('foo',"a")->{foo}, "A", "set/get");
$cache->set('foo',"b", $b);
my ($a1, $b1) = @{$cache->mget([['foo',"a"],['foo',"b"]])};
is($a1->{foo}, "A", "mget first value");
is($b1->{foo}, "B", "mget second value");
$cache->delete('foo',"a");
is(eval{$cache->get('foo',"a")}, undef, 'delete');
$cache->flush;
is(eval{$cache->get('foo',"b")}, undef, 'flush');
