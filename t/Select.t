use Test::More tests => 28;
use Tie::IxHash;
use lib '../lib';

use_ok( 'SimpleDB::Class::Select' );

my $select = SimpleDB::Class::Select->new(
    domain_name      => 'test',
    );

isa_ok($select, 'SimpleDB::Class::Select');

is($select->to_sql, 'select * from `test`', "simple query");

is($select->quote_value("this that"), q{'this that'}, "no escape");
is($select->quote_value("this 'that'"), q{'this ''that'''}, "hq escape");
is($select->quote_value(q{this "that"}), q{'this ""that""'}, "quote escape");
is($select->quote_value(q{this "'that'"}), q{'this ""''that''""'}, "both escape");

$select = SimpleDB::Class::Select->new(
    domain_name     => 'test',
    output          => 'count(*)',
    );
is($select->to_sql, 'select count(*) from `test`', "count query");

$select = SimpleDB::Class::Select->new(
    domain_name     => 'test',
    output          => 'foo',
    );
is($select->to_sql, 'select `foo` from `test`', "single item output query");

$select = SimpleDB::Class::Select->new(
    domain_name     => 'test',
    output          => ['foo','bar'],
    );
is($select->to_sql, 'select `foo`, `bar` from `test`', "multi-item output query");

$select = SimpleDB::Class::Select->new(
    domain_name     => 'test',
    limit           => 44,
    );
is($select->to_sql, 'select * from `test` limit 44', "limit query");

$select = SimpleDB::Class::Select->new(
    domain_name     => 'test',
    order_by        => 'foo',
    );
is($select->to_sql, 'select * from `test` order by `foo` asc', "sort query");

$select = SimpleDB::Class::Select->new(
    domain_name     => 'test',
    order_by        => ['foo','desc'],
    );
is($select->to_sql, 'select * from `test` order by `foo` desc', "sort query descending");

$select = SimpleDB::Class::Select->new(
    domain_name     => 'test',
    order_by        => ['foo'],
    );
is($select->to_sql, 'select * from `test` order by `foo` desc', "sort query implied descending");

$select = SimpleDB::Class::Select->new(
    domain_name     => 'test',
    where           => { 'foo' => ['>', '3']},
    );
is($select->to_sql, "select * from `test` where `foo`>'3'", "query with < where");

$select = SimpleDB::Class::Select->new(
    domain_name     => 'test',
    where           => { 'foo' => ['<', '3']},
    );
is($select->to_sql, "select * from `test` where `foo`<'3'", "query with < where");

$select = SimpleDB::Class::Select->new(
    domain_name     => 'test',
    where           => { 'foo' => ['>=', '3']},
    );
is($select->to_sql, "select * from `test` where `foo`>='3'", "query with >= where");

$select = SimpleDB::Class::Select->new(
    domain_name     => 'test',
    where           => { 'foo' => ['<=', '3']},
    );
is($select->to_sql, "select * from `test` where `foo`<='3'", "query with <= where");

$select = SimpleDB::Class::Select->new(
    domain_name     => 'test',
    where           => { 'foo' => ['!=', '3']},
    );
is($select->to_sql, "select * from `test` where `foo`!='3'", "query with != where");

$select = SimpleDB::Class::Select->new(
    domain_name     => 'test',
    where           => { 'foo' => ['like', '3%']},
    );
is($select->to_sql, "select * from `test` where `foo` like '3%'", "query with like where");

$select = SimpleDB::Class::Select->new(
    domain_name     => 'test',
    where           => { 'foo' => ['not like', '3%']},
    );
is($select->to_sql, "select * from `test` where `foo` not like '3%'", "query with not like where");

$select = SimpleDB::Class::Select->new(
    domain_name     => 'test',
    where           => { 'foo' => ['between', 2,5]},
    );
is($select->to_sql, "select * from `test` where `foo` between '2' and '5'", "query with between where");

$select = SimpleDB::Class::Select->new(
    domain_name     => 'test',
    where           => { 'foo' => ['in', 2,5,7]},
    );
is($select->to_sql, "select * from `test` where `foo` in ('2', '5', '7')", "query with in where");

$select = SimpleDB::Class::Select->new(
    domain_name     => 'test',
    where           => { 'foo' => ['every', 2,5,7]},
    );
is($select->to_sql, "select * from `test` where every(`foo`) in ('2', '5', '7')", "query with every where");

tie my %intersection, 'Tie::IxHash', foo=>2, bar=>'this';
$select = SimpleDB::Class::Select->new(
    domain_name     => 'test',
    where           => { '-intersection' => \%intersection},
    );
is($select->to_sql, "select * from `test` where (`foo`='2' intersection `bar`='this')", "query with or where");

tie my %or, 'Tie::IxHash', foo=>2, bar=>'this';
$select = SimpleDB::Class::Select->new(
    domain_name     => 'test',
    where           => { '-or' => \%or},
    );
is($select->to_sql, "select * from `test` where (`foo`='2' or `bar`='this')", "query with or where");

tie my %and, 'Tie::IxHash', bar=>'this', that=>1;
tie my %or, 'Tie::IxHash', foo=>2, '-and'=>\%and;
$select = SimpleDB::Class::Select->new(
    domain_name     => 'test',
    where           => { '-or' => \%or},
    );
is($select->to_sql, "select * from `test` where (`foo`='2' or (`bar`='this' and `that`='1'))", "query with or where");

tie my %where, 'Tie::IxHash', foo=>2, bar=>'this';
$select = SimpleDB::Class::Select->new(
    domain_name     => 'test',
    order_by        => ['foo'],
    limit           => 44,
    where           => \%where,
    output          => 'that',
    );
is($select->to_sql, "select `that` from `test` where `foo`='2' and `bar`='this' order by `foo` desc limit 44", "everything query");

