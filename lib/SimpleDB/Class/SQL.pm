package SimpleDB::Class::SQL;

use Moose;
use DateTime;
use DateTime::Format::Strptime;

has 'output' => (
    is              => 'ro',
    default         => '*',
);

has 'domain' => (
    is              => 'ro',
    required        => 1,
);

has 'where' => (
    is              => 'ro',
    predicate       => 'has_where',
);

has 'order_by' => (
    is              => 'ro',
    predicate       => 'has_order_by',
);

has 'limit' => (
    is              => 'ro',
    predicate       => 'has_limit',
);

#--------------------------------------------------------
sub quote_value {
    my ($self, $string) = @_;
    $string =~ s/'/''/g;
    $string =~ s/"/""/g;
    return "'".$string."'";
}

#--------------------------------------------------------
sub quote_attribute {
    my ($self, $string) = @_;
    $string =~ s/`/``/g;
    return "`".$string."`";
}

#--------------------------------------------------------
sub parse_datetime {
    my ($self, $value) = @_;
    return DateTime::Format::Strptime::strptime('%Y%m%d%H%M%S%N%z',$value) || DateTime->now;
}

#--------------------------------------------------------
sub parse_int {
    my ($self, $value) = @_;
    return $value-1000000000;
}

#--------------------------------------------------------
sub parse_value {
    my ($self, $name, $value) = @_;
    my $registered_attributes = $self->domain->attributes;
    # set default value
    $value ||= $registered_attributes->{$name};
    # find isa
    my $isa = $registered_attributes->{$name}{isa} || '';
    # pad integers
    if ($isa eq 'Int') {
        $value = $self->parse_int($value); 
    }
    # stringify dates
    elsif ($isa eq 'DateTime') {
        $value = $self->parse_datetime($value);
    }
    return $value;
}

#--------------------------------------------------------
sub format_datetime {
    my ($self, $value) = @_;
    return DateTime::Format::Strptime::strftime('%Y%m%d%H%M%S%N%z',$value);
}

#--------------------------------------------------------
sub format_int {
    my ($self, $value) = @_;
    return sprintf("%010d",$value+1000000000);
}

#--------------------------------------------------------
sub format_value {
    my ($self, $name, $value) = @_;
    my $registered_attributes = $self->domain->attributes;
    # set default value
    $value ||= $registered_attributes->{$name};
    # find isa
    my $isa = $registered_attributes->{$name}{isa} || '';
    # pad integers
    if ($isa eq 'Int') {
        $value = $self->format_int($value); 
    }
    # stringify dates
    elsif ($isa eq 'DateTime') {
        $value = $self->format_datetime($value);
    }
    # quote it
    return $self->quote_value($value);
}

#--------------------------------------------------------
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
                    push @sets, $attribute.'>'.$self->format_value($key, $value->[0]);
                }
                elsif ($cmp eq '<') {
                    push @sets, $attribute.'<'.$self->format_value($key, $value->[0]);
                }
                elsif ($cmp eq '<=') {
                    push @sets, $attribute.'<='.$self->format_value($key, $value->[0]);
                }
                elsif ($cmp eq '>=') {
                    push @sets, $attribute.'>='.$self->format_value($key, $value->[0]);
                }
                elsif ($cmp eq '!=') {
                    push @sets, $attribute.'!='.$self->format_value($key, $value->[0]);
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
                    push @sets, $attribute.'='.$self->format_value($key, $value);
                }
            }
        }
    }
    return join($op, @sets);
}

#--------------------------------------------------------
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
        $where = $self->recurse_where($self->where);
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

    print 'select '.$output.' from '.$self->quote_attribute($self->domain->name).$where.$sort.$limit."\n";
    return 'select '.$output.' from '.$self->quote_attribute($self->domain->name).$where.$sort.$limit;
}



no Moose;
__PACKAGE__->meta->make_immutable;
