use Test::More tests => 21;
use lib '../lib';
use DateTime;
use DateTime::Format::Strptime;

use SimpleDB::Class::Types ':all';


# str
ok(ref to_SdbArrayRefOfStr('test') eq 'ARRAY', 'coerce str to array');

# int
ok(is_SdbIntAsStr('000000999999996'), 'can identify int as string');
is(to_SdbIntAsStr(-4), '000000999999996', 'coersion from int to string');
ok(is_SdbInt(-4), 'can identify int');
is(to_SdbInt('000000999999996'), -4, 'coersion from string to int');
my @aofi = (1,-2,3);
my @aofis = ('000001000000001','000000999999998','000001000000003');
is(to_SdbArrayRefOfIntAsStr(\@aofi)->[1], $aofis[1], 'array of int converts to array of int str');
ok(ref to_SdbArrayRefOfInt(1) eq 'ARRAY', 'coerce int to array');

# date
my $dt = DateTime->now;
my $dts = DateTime::Format::Strptime::strftime('%Y-%m-%d %H:%M:%S %N %z',$dt);
ok(is_SdbDateTimeAsStr($dts), 'can identify DateTime as string');
is(to_SdbDateTimeAsStr($dt), $dts, 'coersion from DateTime to string');
ok(is_SdbDateTime($dt), 'can identify DateTime');
is(to_SdbDateTime($dts), $dt, 'coersion from string to DateTime');
is(to_SdbDateTime(''), $dt, 'coersion from empty to DateTime');
is(to_SdbDateTime(), $dt, 'coersion from undef to DateTime');
is(to_SdbArrayRefOfDateTimeAsStr([$dt])->[0], $dts, 'array ref of date time coerced to array ref of date time as str');
ok(ref to_SdbArrayRefOfDateTime($dt) eq 'ARRAY', 'coerce datetime to array');

# hash
my $h = { foo=>'bar' };
my $hs = '{"foo":"bar"}';
ok(is_SdbHashRefAsStr($hs), 'can identify hashref as string');
is(to_SdbHashRefAsStr($h), $hs, 'coersion from hashref to string');
ok(is_SdbHashRef($h), 'can identify hashref');
is(to_SdbHashRef($hs)->{foo}, 'bar', 'coersion from string to hashref');
is(to_SdbArrayRefOfHashRefAsStr([$h])->[0], $hs, 'array ref of hash ref coerced to array ref of hash ref str');
ok(ref to_SdbArrayRefOfHashRef($h) eq 'ARRAY', 'coerce hash ref to array');



