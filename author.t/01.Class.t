use Test::More tests => 3;
use lib '../lib';

use SimpleDB::Class;

my $access = $ENV{SIMPLEDB_ACCESS_KEY};
my $secret = $ENV{SIMPLEDB_SECRET_KEY};

unless (defined $access && defined $secret) {
    die "You need to set environment variables SIMPLEDB_ACCESS_KEY and SIMPLEDB_SECRET_KEY to run these tests.";
}
my $db = SimpleDB::Class->new(secret_key=>$secret, access_key=>$access, cache_servers=>[{host=>'127.0.0.1', port=>11211}]);
ok($db->send_request('CreateDomain',{DomainName=>'xxxx'}), 'try creating a domain');
my $domains = $db->list_domains;

is(ref $domains, 'ARRAY', 'list_domains returns an array ref');

ok(grep({$_ eq 'xxxx'} @{$domains}), 'got created domain');

END {
    $db->send_request('DeleteDomain', {DomainName=>'xxxx'});
}

