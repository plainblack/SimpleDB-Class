use Test::More tests => 4;
use lib '../lib';

use_ok( 'SimpleDB::Class' );

diag( "Testing SimpleDB::Class $SimpleDB::Class::VERSION" );

my $db = SimpleDB::Class->new(secret_key=>'secretxx', access_key=>'accessyy', cache_servers=>[{'socket' => '/tmp/foo/bar'}]);

isa_ok($db, 'SimpleDB::Class');
isa_ok($db->cache, 'SimpleDB::Class::Cache');
isa_ok($db->http, 'SimpleDB::Class::HTTP');



# everything else requires a connection
