package SimpleDB::Class::Types;

use warnings;
use strict;
use DateTime;
use DateTime::Format::Strptime;
use JSON;

use MooseX::Types 
    -declare => [qw(SdbArrayRefOfDateTime SdbDateTimeAsStr SdbDateTime SdbArrayRefOfDateTimeAsStr
        SdbArrayRefOfStr SdbStr
        SdbArrayRefOfInt SdbIntAsStr SdbInt SdbArrayRefOfIntAsStr
        SdbArrayRefOfHashRef SdbHashRefAsStr SdbHashRef SdbArrayRefOfHashRefAsStr
    )];

use MooseX::Types::Moose qw/Int HashRef ArrayRef Str Undef/;

# Str

subtype SdbStr,
    as Str;

coerce SdbStr,
    from Undef, via { '' };

subtype SdbArrayRefOfStr,
    as ArrayRef[SdbStr];

coerce SdbArrayRefOfStr,
    from SdbStr, via { [ $_ ] };

# DateTime

class_type 'DateTime';

subtype SdbDateTime,
    as 'DateTime';

subtype SdbArrayRefOfDateTime,
    as ArrayRef[SdbDateTime];

coerce SdbArrayRefOfDateTime,
    from SdbDateTime, via { [ $_ ] };

subtype SdbDateTimeAsStr,
    as SdbStr,
    where { $_ =~ m/\d{4}-\d\d-\d\d \d\d:\d\d:\d\d \d+ \+\d{4}/ },
    message { 'Not a vaild date string.' };

subtype SdbArrayRefOfDateTimeAsStr,
    as ArrayRef[SdbDateTimeAsStr];

coerce SdbDateTime,
    from SdbDateTimeAsStr, via { DateTime::Format::Strptime::strptime('%Y-%m-%d %H:%M:%S %N %z', $_) },
    from Undef, via { DateTime->now },
    from SdbStr, via { DateTime->now };

coerce SdbDateTimeAsStr,
    from SdbDateTime, via { DateTime::Format::Strptime::strftime('%Y-%m-%d %H:%M:%S %N %z', $_) };

coerce SdbArrayRefOfDateTimeAsStr,
    from SdbArrayRefOfDateTime, via { 
        my $array_ref_of_date_time = shift;
        my @array_of_date_time_as_str = map { to_SdbDateTimeAsStr($_) } @{$array_ref_of_date_time};
        return \@array_of_date_time_as_str;
        };


# Int    

subtype SdbInt,
    as Int,
    where { !is_SdbIntAsStr($_) };

subtype SdbArrayRefOfInt,
    as ArrayRef[SdbInt];

coerce SdbArrayRefOfInt,
    from SdbInt, via { [ $_ ] };

subtype SdbIntAsStr,
    as SdbStr,
    where { $_ =~ m/^\d{15}$/ },
    message { 'Not a valid int string.' };

subtype SdbArrayRefOfIntAsStr,
    as ArrayRef[SdbIntAsStr];

coerce SdbInt,
    from SdbIntAsStr, via { $_ - 1000000000 };
    from Undef, via { 0 };

coerce SdbIntAsStr,
    from SdbInt, via { sprintf("%015d", ($_ + 1000000000)) };

coerce SdbArrayRefOfIntAsStr,
    from SdbArrayRefOfInt, via { 
        my $array_ref_of_int = shift;
        my @array_of_int_as_str = map { to_SdbIntAsStr($_) } @{$array_ref_of_int};
        return \@array_of_int_as_str;
        };


# HashRef

subtype SdbHashRef,
    as HashRef;

subtype SdbArrayRefOfHashRef,
    as ArrayRef[SdbHashRef];

coerce SdbArrayRefOfHashRef,
    from SdbHashRef, via { [ $_ ] };

subtype SdbHashRefAsStr,
    as SdbStr,
    where { eval{JSON::from_json($_)}; ($@) ? 0 : 1; },
    message { 'Not a valid hash string.' };

subtype SdbArrayRefOfHashRefAsStr,
    as ArrayRef[SdbHashRefAsStr];

coerce SdbHashRef,
    from SdbHashRefAsStr, via { JSON::from_json($_) },
    from Undef, via { {} },
    from SdbStr, via { {} };

coerce SdbHashRefAsStr,
    from SdbHashRef, via { JSON->new->canonical->encode($_) },
    from Undef, via { '{}' },
    from SdbStr, via { '{}' };

coerce SdbArrayRefOfHashRefAsStr,
    from SdbArrayRefOfHashRef, via { 
        my $array_ref_of_hash_ref = shift;
        my @array_of_hash_ref_as_str = map { to_SdbHashRefAsStr($_) } @{$array_ref_of_hash_ref};
        return \@array_of_hash_ref_as_str;
        };


1;

