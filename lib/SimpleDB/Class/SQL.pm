package SimpleDB::Class::SQL;

=head1 NAME

SimpleDB::Class::SQL - SQL generation tools for SimpleDB.

=head1 DESCRIPTION

This class is used to generate the SQL needed for the Select operation on SimpleDB's web service.

=head1 METHODS

The following methods are available from this class.

=cut

use Moose;
use JSON;
use DateTime;
use DateTime::Format::Strptime;
use Clone qw(clone);

#--------------------------------------------------------

=head2 new ( params )

Constructor. 

=head3 params

A hash of options you can pass in to the constructor.

=head4 item_class

A L<SimpleDB::Class::Item> subclass name. This is required.

=head4 output

Defaults to '*'. Alternatively you can pass a string of 'count(*)' or an attribute. Or you can pass an array ref of attributes.

=head4 where

A hash reference containing a series of clauses. Here are some examples and what the resulting queries would be. You can of course combine all these options to create your own queries.

Direct comparison.

 { foo => 1 }

 select * from domain where foo=1

 { foo => 1, bar => 2 }

 select * from domain where foo=1 and bar=2

 { foo => [ '>', 5 ] } # '=', '!=', '>', '<', '<=', '>='

 select * from domain where foo > 5

Direct comparison with an or clause.

 { -or => {  foo => 1, bar => 2 } }
 
 select * from domain where (foo=1 or bar=2)

Find all items where these attributes intersect.

 { -intersection => {  foo => 1, bar => 2 } }
 
 select * from domain where (foo=1 intersection bar=2)

Combining OR and AND.

 { -or => {  foo => 1, -and => { this => 'that', bar => 2 } }
 
 select * from domain where (foo=1 or ( this='that' and bar=2 ))

Finding within a range.

 { foo=>['between', 5, 10] }

 select * from domain where foo between 5 and 10

Finding within a set.

 { foo => ['in', 1, 3, 5, 7 ] }

 select * from domain where foo in (1, 3, 5, 7)

Finding in a set where every item returned matches all members of the set.

 { foo => ['every', 1, 3, 5, 7 ] }

 select * from domain where every(foo) in (1, 3, 5, 7)

String comparisons. You can match on either side of the string ('%this', 'that%') or both ('%this%'). Note that matching at the beginning or both sides of the string is a slow operation.

 { foo => [ 'like', 'this%' ] } # 'not like'

 select * from domain where foo like 'this%'

Null comparisons. These are very slow. Try inserting 'Null' or 'None' into a field and do string comparisons rather than null comparisons.

 { foo => 'is null' } # 'is not null'

 select * from domain where foo is null

=head4 order_by

An attribute to order the result set by, defaults to ascending order. Can also pass in an array ref containing an attribute and 'desc' or 'asc'. If an array ref is passed in containing only an attribute name it is an implied descending order.

 "foo"

 ["foo","desc"]

 ["foo"]

=head4 limit

An integer of a number of items to limit the result set to.

=cut

#--------------------------------------------------------

=head2 output ()

Returns what was passed into the constructor for the output field.

=cut

has output => (
    is              => 'ro',
    default         => '*',
);

#--------------------------------------------------------

=head2 item_class ()

Returns what was passed into the constructor for the item_class field.

=cut

has item_class => (
    is              => 'ro',
    required        => 1,
);

#--------------------------------------------------------

=head2 where ()

Returns what was passed into the constructor for the where field.

=head2 has_where()

Returns a boolean indicating whether a where clause has been set.

=cut

has where => (
    is              => 'ro',
    predicate       => 'has_where',
);

#--------------------------------------------------------

=head2 order_by ()

Returns what was passed into the constructor for the output field.

=head2 has_order_by ()

Returns a boolean indicating whether an order by clause has been set.

=cut

has order_by => (
    is              => 'ro',
    predicate       => 'has_order_by',
);

#--------------------------------------------------------

=head2 limit ()

Returns what was passed into the constructor for the output field.

=head2 has_limit ()

=cut

has limit => (
    is              => 'ro',
    predicate       => 'has_limit',
);

#--------------------------------------------------------

=head2 quote_value ( string )

Escapes ' and " in values.

=head3 string

The value to escape.

=cut

sub quote_value {
    my ($self, $string) = @_;
    $string =~ s/'/''/g;
    $string =~ s/"/""/g;
    return "'".$string."'";
}

#--------------------------------------------------------

=head2 quote_attribute ( string )

Escapes an attribute with so that it can contain spaces and other special characters by wrapping it in backticks `.

=head3 string

The attribute name to escape.

=cut

sub quote_attribute {
    my ($self, $string) = @_;
    $string =~ s/`/``/g;
    return "`".$string."`";
}

#--------------------------------------------------------

=head2 parse_datetime ( string )

Parses a date time string and returns a L<DateTime> object.

=head3 string

A string in the format of YY-MM-DD HH:MM:SS NNNNNNN +ZZZZ where NNNNNNN represents nanoseconds and +ZZZZ represents an ISO timezone.

=cut

sub parse_datetime {
    my ($self, $value) = @_;
    if ($value =~ m/\d{4}-\d\d-\d\d \d\d:\d\d:\d\d \d+ +\d{4}/) {
        return DateTime::Format::Strptime::strptime('%Y-%m-%d %H:%M:%S %N %z',$value);
    }
    else {
        return DateTime->now;
    }
}

#--------------------------------------------------------

=head2 parse_hashref ( string ) 

Parses a JSON formatted string and returns an actual hash reference.

=head3 string

A string that is composed of a JSONified hash reference. 

=cut

sub parse_hashref {
    my ($self, $value) = @_;
    if ($value eq '') {
        return {};
    }
    else {
        return JSON::from_json($value);
    }
}

#--------------------------------------------------------

=head2 parse_int ( string ) 

Parses an integer formatted string and returns an actual integer.

B<Warning:> SimpleDB::Class only supports 15 digit positive integers and 9 digit negative integers.

=head3 string

A string that is composed of an integer + 1000000000 and then padded to have preceding zeros so that it's always 15 characters long.

=cut

sub parse_int {
    my ($self, $value) = @_;
    $value ||= '000001000000000';
    return $value-1000000000;
}

#--------------------------------------------------------

=head2 parse_value ( name, value ) 

Returns a value that has been passed through one of the parse_* methods in this class.

=head3 name

The name of the attribute to parse.

=head3 value

The current stringified value to parse.

=cut

sub parse_value {
    my ($self, $name, $value) = @_;
    my $registered_attributes = $self->item_class->attributes;
    # set default value
    $value ||= $registered_attributes->{$name}{default};
    # find isa
    my $isa = $registered_attributes->{$name}{isa} || '';
    # unpad integers
    if ($isa eq 'Int') {
        $value = $self->parse_int($value); 
    }
    # unjsonify hash refs
    elsif ($isa eq 'HashRef') {
        $value = $self->parse_hashref($value);
    }
    # unstringify dates
    elsif ($isa eq 'DateTime') {
        $value = $self->parse_datetime($value);
    }
    return $value;
}

#--------------------------------------------------------

=head2 format_datetime ( value )

Returns a string formatted datetime object. Example: 2009-12-01 10:43:01 04939911 +0600. See parse_datetime, as this is the reverse of that.

=head3 value

A L<DateTime> object.

=cut

sub format_datetime {
    my ($self, $value) = @_;
    $value ||= DateTime->now;
    return DateTime::Format::Strptime::strftime('%Y-%m-%d %H:%M:%S %N %z',$value);
}

#--------------------------------------------------------

=head2 format_hashref ( value )

Returns a json formatted hashref. Example: C<{"foo":"bar"}>. See parse_hashref as this is the reverse of that. 

B<Warning:> The total length of your hash reference after it's turned into JSON cannot exceed 1024 characters, as that's the field size limit for SimpleDB. Failing to heed this warning will result in corrupt data.

=head3 value

A hash reference.

=cut

sub format_hashref {
    my ($self, $value) = @_;
    unless (ref $value eq 'HASH') {
        $value = {};
    }
    return JSON::to_json($value);
}

#--------------------------------------------------------

=head2 format_int ( value )

Returns a string formatted integer. Example: 000000003495839. See parse_integer as this is the reverse of that. 

B<Warning:> SimpleDB::Class only supports 15 digit positive integers and 9 digit negative integers.

=head3 value

An integer.

=cut

sub format_int {
    my ($self, $value) = @_;
    $value ||= 0; # init
    return sprintf("%015d",$value+1000000000);
}

#--------------------------------------------------------

=head2 format_value ( name, value, [ skip_quotes ] )

Formats an attribute as a string using one of the format_* methods in this class. See parse_value, as this is the reverse of that.

=head3 name

The name of the attribute to format.

=head3 value

The value to format.

=head3 skip_quotes

A boolean indicating whether or not to skip calling the quote_value function on the whole thing.

=cut

sub format_value {
    my ($self, $name, $value, $skip_quotes) = @_;
    my $registered_attributes = $self->item_class->attributes;
    # set default value
    $value ||= $registered_attributes->{$name}{default};
    # find isa
    my $isa = $registered_attributes->{$name}{isa} || '';
    # pad integers
    if ($isa eq 'Int') {
        $value = $self->format_int($value); 
    }
    # jsonify hashrefs
    elsif ($isa eq 'HashRef') {
        $value = $self->format_hashref($value); 
    }
    # stringify dates
    elsif ($isa eq 'DateTime') {
        $value = $self->format_datetime($value);
    }
    # quote it
    return ($skip_quotes) ? $value : $self->quote_value($value);
}

#--------------------------------------------------------

=head2 recurese_where ( constraints, [ op ] )

Traverses a where() hierarchy and returns a stringified SQL version of the where clause.

=head3 constraints

A portion of a where hierarchy, perhaps broken off from the main for detailed analysis.

=head3 op

If it's a chunk broken off, -and, -or, -intersection then the operator will be passed through here. 

=cut

sub recurse_where {
    my ($self, $constraints, $op) = @_;
    $op ||= ' and ';
    my @sets;
    foreach my $key (keys %{$constraints}) {
        if ($key eq '-and') {
            push @sets, '('.$self->recurse_where($constraints->{$key}, ' and ').')';
        }
        elsif ($key eq '-or') {
            push @sets, '('.$self->recurse_where($constraints->{$key}, ' or ').')';
        }
        elsif ($key eq '-intersection') {
            push @sets, '('.$self->recurse_where($constraints->{$key}, ' intersection ').')';
        }
        else {
            my $value = $constraints->{$key};
            my $attribute = $self->quote_attribute($key);
            if (ref $value eq 'ARRAY') {
                my $cmp = shift @{$value};
                if ($cmp eq '>') {
                    push @sets, $attribute.' > '.$self->format_value($key, $value->[0]);
                }
                elsif ($cmp eq '<') {
                    push @sets, $attribute.' < '.$self->format_value($key, $value->[0]);
                }
                elsif ($cmp eq '<=') {
                    push @sets, $attribute.' <= '.$self->format_value($key, $value->[0]);
                }
                elsif ($cmp eq '>=') {
                    push @sets, $attribute.' >= '.$self->format_value($key, $value->[0]);
                }
                elsif ($cmp eq '!=') {
                    push @sets, $attribute.' != '.$self->format_value($key, $value->[0]);
                }
                elsif ($cmp eq 'like') {
                    push @sets, $attribute.' like '.$self->format_value($key, $value->[0]);
                }
                elsif ($cmp eq 'not like') {
                    push @sets, $attribute.' not like '.$self->format_value($key, $value->[0]);
                }
                elsif ($cmp eq 'in') {
                    my @values = map {$self->format_value($key, $_)} @{$value};
                    push @sets, $attribute.' in ('.join(', ', @values).')';
                }
                elsif ($cmp eq 'every') {
                    my @values = map {$self->format_value($key, $_)} @{$value};
                    push @sets, 'every('.$attribute.') in ('.join(', ', @values).')';
                }
                elsif ($cmp eq 'between') {
                    push @sets, $attribute.' between '.$self->format_value($key, $value->[0]).' and '.$self->format_value($key, $value->[1])
                }
            }
            else {
                my $value = $constraints->{$key};
                if ($value eq 'is null') {
                    push @sets, $attribute.' is null';
                }
                elsif ($value eq 'is not null') {
                    push @sets, $attribute.' is not null';
                }
                else {
                    push @sets, $attribute.' = '.$self->format_value($key, $value);
                }
            }
        }
    }
    return join($op, @sets);
}

#--------------------------------------------------------

=head2 to_sql ( ) 

Returns the entire query as a stringified SQL version.

=cut

sub to_sql {
    my ($self) = @_;

    # output
    my $output = $self->output;
    if (ref $output eq 'ARRAY') {
        my @fields = map {$self->quote_attribute($_)} @{$output};
        $output = join ', ', @fields;
    }
    elsif ($output ne '*' && $output ne 'count(*)') {
        $output = $self->quote_attribute($output);
    }

    # where
    my $where='';
    if ($self->has_where) {
        $where = $self->recurse_where(clone($self->where));
        if ($where ne '') {
            $where = ' where '.$where;
        }
    }

    # sort
    my $sort='';
    if ($self->has_order_by) {
        my $by = $self->order_by;
        my $direction = 'asc';
        if (ref $by eq 'ARRAY') {
            ($by, $direction) = @{$by};
            $direction ||= 'desc';
        }
        $sort = ' order by '.$self->quote_attribute($by).' '.$direction;
    }

    # limit
    my $limit='';
    if ($self->has_limit) {
        $limit = ' limit '.$self->limit;
    }

    return 'select '.$output.' from '.$self->quote_attribute($self->item_class->can('domain_name')->()).$where.$sort.$limit;
}


=head1 LEGAL

SimpleDB::Class is Copyright 2009 Plain Black Corporation (L<http://www.plainblack.com/>) and is licensed under the same terms as Perl itself.

=cut

no Moose;
__PACKAGE__->meta->make_immutable;
