use Test::More tests => 15;
use Test::Deep;
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

tie my %where, 'Tie::IxHash', foo=>2, bar=>'this';
$select = SimpleDB::Class::Select->new(
    domain_name     => 'test',
    order_by        => ['foo'],
    limit           => 44,
    where           => \%where,
    output          => 'that',
    );
is($select->to_sql, "select `that` from `test` where `foo`='2' and `bar`='this' order by `foo` desc limit 44", "everything query");

