use Test::More tests => 30;
use Tie::IxHash;
use lib ('../lib', 'lib');
use DateTime;
use DateTime::Format::Strptime;

my $access = $ENV{SIMPLEDB_ACCESS_KEY};
my $secret = $ENV{SIMPLEDB_SECRET_KEY};

unless (defined $access && defined $secret) {
    die "You need to set environment variables SIMPLEDB_ACCESS_KEY and SIMPLEDB_SECRET_KEY to run these foo_domains.";
}


use Foo;

my $foo = Foo->new(secret_key=>$secret, access_key=>$access, cache_servers=>[{host=>'127.0.0.1', port=>11211}]);

my $domain = $foo->domain('foo_domain');

use_ok( 'SimpleDB::Class::SQL' );
my $select = SimpleDB::Class::SQL->new(
    domain      => $domain,
    );

isa_ok($select, 'SimpleDB::Class::SQL');

is($select->to_sql, 'select * from `foo_domain`', "simple query");

is($select->quote_value("this that"), q{'this that'}, "no escape");
is($select->quote_value("this 'that'"), q{'this ''that'''}, "hq escape");
is($select->quote_value(q{this "that"}), q{'this ""that""'}, "quote escape");
is($select->quote_value(q{this "'that'"}), q{'this ""''that''""'}, "both escape");
is($select->format_value('unknown', 'that'), q{'that'}, "format a string");
is($select->format_int(45), q{1000000045}, "format a number");

$select = SimpleDB::Class::SQL->new(
    domain          => $domain,
    output          => 'count(*)',
    );
is($select->to_sql, 'select count(*) from `foo_domain`', "count query");

$select = SimpleDB::Class::SQL->new(
    domain          => $domain,
    output          => 'color',
    );
is($select->to_sql, 'select `color` from `foo_domain`', "single item output query");

$select = SimpleDB::Class::SQL->new(
    domain          => $domain,
    output          => ['color','size'],
    );
is($select->to_sql, 'select `color`, `size` from `foo_domain`', "multi-item output query");

$select = SimpleDB::Class::SQL->new(
    domain          => $domain,
    limit           => 44,
    );
is($select->to_sql, 'select * from `foo_domain` limit 44', "limit query");

$select = SimpleDB::Class::SQL->new(
    domain          => $domain,
    order_by        => 'color',
    );
is($select->to_sql, 'select * from `foo_domain` order by `color` asc', "sort query");

$select = SimpleDB::Class::SQL->new(
    domain          => $domain,
    order_by        => ['color','desc'],
    );
is($select->to_sql, 'select * from `foo_domain` order by `color` desc', "sort query descending");

$select = SimpleDB::Class::SQL->new(
    domain          => $domain,
    order_by        => ['color'],
    );
is($select->to_sql, 'select * from `foo_domain` order by `color` desc', "sort query implied descending");

$select = SimpleDB::Class::SQL->new(
    domain          => $domain,
    where           => { 'quantity' => ['>', 3]},
    );
is($select->to_sql, "select * from `foo_domain` where `quantity`>'1000000003'", "query with < where");

my $dt = DateTime->now;
$select = SimpleDB::Class::SQL->new(
    domain          => $domain,
    where           => { 'start_date' => ['<', $dt]},
    );
is($select->to_sql, "select * from `foo_domain` where `start_date`<'".DateTime::Format::Strptime::strftime('%Y-%m-%d %H:%M:%S %N %z',$dt)."'", "query with < where");

$select = SimpleDB::Class::SQL->new(
    domain          => $domain,
    where           => { 'quantity' => ['>=', -99999]},
    );
is($select->to_sql, "select * from `foo_domain` where `quantity`>='0999900001'", "query with >= where");

$select = SimpleDB::Class::SQL->new(
    domain          => $domain,
    where           => { 'color' => ['<=', '3']},
    );
is($select->to_sql, "select * from `foo_domain` where `color`<='3'", "query with <= where");

$select = SimpleDB::Class::SQL->new(
    domain          => $domain,
    where           => { 'color' => ['!=', '3']},
    );
is($select->to_sql, "select * from `foo_domain` where `color`!='3'", "query with != where");

$select = SimpleDB::Class::SQL->new(
    domain          => $domain,
    where           => { 'color' => ['like', '3%']},
    );
is($select->to_sql, "select * from `foo_domain` where `color` like '3%'", "query with like where");

$select = SimpleDB::Class::SQL->new(
    domain          => $domain,
    where           => { 'color' => ['not like', '3%']},
    );
is($select->to_sql, "select * from `foo_domain` where `color` not like '3%'", "query with not like where");

$select = SimpleDB::Class::SQL->new(
    domain          => $domain,
    where           => { 'color' => ['between', 2,5]},
    );
is($select->to_sql, "select * from `foo_domain` where `color` between '2' and '5'", "query with between where");

$select = SimpleDB::Class::SQL->new(
    domain          => $domain,
    where           => { 'color' => ['in', 2,5,7]},
    );
is($select->to_sql, "select * from `foo_domain` where `color` in ('2', '5', '7')", "query with in where");

$select = SimpleDB::Class::SQL->new(
    domain          => $domain,
    where           => { 'color' => ['every', 2,5,7]},
    );
is($select->to_sql, "select * from `foo_domain` where every(`color`) in ('2', '5', '7')", "query with every where");

tie my %intersection, 'Tie::IxHash', color=>2, size=>'this';
$select = SimpleDB::Class::SQL->new(
    domain          => $domain,
    where           => { '-intersection' => \%intersection},
    );
is($select->to_sql, "select * from `foo_domain` where (`color`='2' intersection `size`='this')", "query with or where");

tie my %or, 'Tie::IxHash', color=>2, size=>'this';
$select = SimpleDB::Class::SQL->new(
    domain          => $domain,
    where           => { '-or' => \%or},
    );
is($select->to_sql, "select * from `foo_domain` where (`color`='2' or `size`='this')", "query with or where");

tie my %and, 'Tie::IxHash', size=>'this', that=>1;
tie my %or, 'Tie::IxHash', color=>2, '-and'=>\%and;
$select = SimpleDB::Class::SQL->new(
    domain          => $domain,
    where           => { '-or' => \%or},
    );
is($select->to_sql, "select * from `foo_domain` where (`color`='2' or (`size`='this' and `that`='1'))", "query with or where");

tie my %where, 'Tie::IxHash', color=>2, size=>'this';
$select = SimpleDB::Class::SQL->new(
    domain          => $domain,
    order_by        => ['color'],
    limit           => 44,
    where           => \%where,
    output          => 'that',
    );
is($select->to_sql, "select `that` from `foo_domain` where `color`='2' and `size`='this' order by `color` desc limit 44", "everything query");

