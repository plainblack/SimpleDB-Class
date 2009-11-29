use Test::More tests => 7;
use Test::Deep;
use lib '../lib';
use SimpleDB::Class;
use SimpleDB::Class::Domain;
use_ok( 'SimpleDB::Class::Item' );

my %attributes = ('foo' => 'xxx');


my $db = SimpleDB::Class->new(secret_key=>'secretxx', access_key=>'accessyy');
my $domain = SimpleDB::Class::Domain->new(name=>'test', simpledb=>$db);
my $item = SimpleDB::Class::Item->new(domain=>$domain, attributes=>\%attributes);

isa_ok($item, 'SimpleDB::Class::Item');

cmp_deeply(
    $item->attributes,
    \%attributes,
    'attributes work'
);

ok($item->can('foo'), 'attributes create accessors');

$item->add_attribute('bar',2);
$attributes->{bar} = 2;

cmp_deeply(
    $item->attributes,
    \%attributes,
    'new attributes work'
);

ok($item->can('bar'), 'new attributes create accessors');

like($item->generate_uuid, qr/^[a-z0-9\-]+$/, 'UUID generator working');

# everything else requires a connection
