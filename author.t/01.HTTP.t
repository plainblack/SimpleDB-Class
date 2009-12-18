use Test::More tests => 4;
use lib '../lib';

use_ok('SimpleDB::Class::HTTP');

my $access = $ENV{SIMPLEDB_ACCESS_KEY};
my $secret = $ENV{SIMPLEDB_SECRET_KEY};

unless (defined $access && defined $secret) {
    die "You need to set environment variables SIMPLEDB_ACCESS_KEY and SIMPLEDB_SECRET_KEY to run these tests.";
}

my $http = SimpleDB::Class::HTTP->new(secret_key=>$secret, access_key=>$access);
isa_ok($http, 'SimpleDB::Class::HTTP');
ok($http->send_request('CreateDomain',{DomainName=>'yyyy'}), 'try creating a domain');

my $result = $http->send_request('ListDomains');
my $domains = $result->{ListDomainsResult}{DomainName};
unless (ref $domains eq 'ARRAY') {
    $domains = [$domains];
}

ok(grep({$_ eq 'yyyy'} @{$domains}), 'got created domain');

$http->send_request('DeleteDomain', {DomainName=>'xxxx'});

