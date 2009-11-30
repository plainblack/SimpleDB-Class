use Test::More tests => 5;
use Test::Deep;
use lib '../lib';

use_ok( 'SimpleDB::Class' );
use SimpleDB::Class::Domain;

diag( "Testing SimpleDB::Class $SimpleDB::Class::VERSION" );

my $db = SimpleDB::Class->new(secret_key=>'secretxx', access_key=>'accessyy');

isa_ok($db, 'SimpleDB::Class');


my $request = $db->construct_request('DoSomething',{foo=>'bar'});

isa_ok($request, 'HTTP::Request');

is($request->method, 'POST', "it's a post request");
like($request->content, qr/^AWSAccessKeyId=accessyy&Action=DoSomething&SignatureMethod=HmacSHA256&SignatureVersion=2&Timestamp=\d{4}-\d{2}-\d{2}T\d{2}%3A\d{2}%3A\d{2}\.000Z&Version=2009-04-15&foo=bar&Signature=[A-Za-z0-9\%]+%3D$/, "request document looks good");

# everything else requires a connection
