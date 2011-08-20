use Test::More tests => 40;
use lib '../lib';
use DateTime;
use DateTime::Format::Strptime;

use SimpleDB::Class::Types ':all';


# str
is(ref to_SdbArrayRefOfStr('test'), 'ARRAY', 'coerce str to array');
ok(is_SdbMediumStr('test'), 'is medium str');
is(to_SdbMediumStr(['001|test']), 'test', 'coerce array str slice to medium str');

# int
is(to_SdbIntAsStr(-4), 'int000000999999996', 'coersion from int to string');
ok(is_SdbInt(-4), 'can identify int');
is(to_SdbInt('int000000999999996'), -4, 'coersion from string to int');
my @aofi = (1,-2,3);
my @aofis = ('int000001000000001','int000000999999998','int000001000000003');
is(to_SdbArrayRefOfIntAsStr(\@aofi)->[1], $aofis[1], 'array of int converts to array of str');
is(to_SdbArrayRefOfInt(\@aofis)->[1], $aofi[1], 'array of str converts to array of int');
ok(ref to_SdbArrayRefOfInt(1) eq 'ARRAY', 'coerce int to array');
is(to_SdbInt(['int000000999999996']), -4, 'coerce array of str to int');
is(to_SdbInt([5]), 5, 'coerce array of int to int');

# decimal 
is(to_SdbDecimalAsStr(-4), 'dec000000999999996', 'coersion from decimal to string');
ok(is_SdbDecimal(-4), 'can identify decimal');
is(to_SdbDecimal('dec000000999999996'), -4, 'coersion from string to decimal');
my @aofi = (1,-2,3);
my @aofis = ('dec000001000000001','dec000000999999998','dec000001000000003');
is(to_SdbArrayRefOfDecimalAsStr(\@aofi)->[1], $aofis[1], 'array of decimal converts to array of str');
is(to_SdbArrayRefOfDecimal(\@aofis)->[1], $aofi[1], 'array of str converts to array of decimal');
ok(ref to_SdbArrayRefOfDecimal(1) eq 'ARRAY', 'coerce decimal to array');
is(to_SdbDecimal(['dec000000999999996']), -4, 'coerce decimal of str to decimal');
is(to_SdbDecimal([5]), 5, 'coerce array of decimal to decimal');


# decimal 
is(to_SdbDecimalAsStr(-4.25), 'dec000000999999996.25', 'coersion from decimal to string');
ok(is_SdbDecimal(-4.25), 'can identify decimal');
is(to_SdbDecimal('dec000000999999996.25'), -4.25, 'coersion from string to decimal');
my @aofi = (1.25,-2.36,3.47);
my @aofis = ('dec000001000000001.25','dec000000999999998.36','dec000001000000003.47');
is(to_SdbArrayRefOfDecimalAsStr(\@aofi)->[1], $aofis[1], 'array of decimal converts to array of str');
is(to_SdbArrayRefOfDecimal(\@aofis)->[1], $aofi[1], 'array of str converts to array of decimal');
ok(ref to_SdbArrayRefOfDecimal(1) eq 'ARRAY', 'coerce decimal to array');
is(to_SdbDecimal(['dec000000999999996.25']), -4.25, 'coerce decimal of str to decimal');
is(to_SdbDecimal([5.25]), 5.25, 'coerce array of decimal to decimal');


# date
my $dt = DateTime->now;
my $dts = DateTime::Format::Strptime::strftime('%Y-%m-%d %H:%M:%S %N %z',$dt);
is(to_SdbStr($dt), $dts, 'coersion from DateTime to string');
ok(is_SdbDateTime($dt), 'can identify DateTime');
is(to_SdbDateTime($dts)->second, $dt->second, 'coersion from string to DateTime');
is(ref to_SdbDateTime(''), 'DateTime', 'coersion from empty to DateTime');
is(ref to_SdbDateTime(), 'DateTime', 'coersion from undef to DateTime');
is(to_SdbArrayRefOfStr([$dt])->[0], $dts, 'array ref of date time coerced to array ref of str');
is(to_SdbArrayRefOfDateTime([$dts])->[0]->second, $dt->second, 'array ref of string coerced to array ref of DateTime');
ok(ref to_SdbArrayRefOfDateTime($dt) eq 'ARRAY', 'coerce datetime to array');
is(to_SdbDateTime([$dts])->second, $dt->second, 'coerce array of str to date time');
is(to_SdbDateTime([$dt])->second, $dt->second, 'coerce array of date time to date time');

# hash
my $h = { foo=>'bar' };
my $hs = '{"foo":"bar"}';
ok(is_SdbHashRef($h), 'can identify hashref');
is(to_SdbHashRef(['001|'.$hs])->{foo}, 'bar', 'coerce array ref of str slice to hash ref');
is(to_SdbArrayRefOfStr($h)->[0], '001|'.$hs, 'coerce hash ref to array ref of str slices');


