package SimpleDB::Class::Select;

use Moose;

has 'output' => (
    is              => 'ro',
    default         => '*',
);

has 'domain_name' => (
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
                    push @sets, $attribute.'>'.$self->quote_value($value->[0]);
                }
                elsif ($cmp eq '<') {
                    push @sets, $attribute.'<'.$self->quote_value($value->[0]);
                }
                elsif ($cmp eq '<=') {
                    push @sets, $attribute.'<='.$self->quote_value($value->[0]);
                }
                elsif ($cmp eq '>=') {
                    push @sets, $attribute.'>='.$self->quote_value($value->[0]);
                }
                elsif ($cmp eq '!=') {
                    push @sets, $attribute.'!='.$self->quote_value($value->[0]);
                }
                elsif ($cmp eq 'like') {
                    push @sets, $attribute.' like '.$self->quote_value($value->[0]);
                }
                elsif ($cmp eq 'not like') {
                    push @sets, $attribute.' not like '.$self->quote_value($value->[0]);
                }
                elsif ($cmp eq 'in') {
                    my @values = map {$self->quote_value($_)} @{$value};
                    push @sets, $attribute.' in ('.join(', ', @values).')';
                }
                elsif ($cmp eq 'every') {
                    my @values = map {$self->quote_value($_)} @{$value};
                    push @sets, 'every('.$attribute.') in ('.join(', ', @values).')';
                }
                elsif ($cmp eq 'between') {
                    push @sets, $attribute.' between '.$self->quote_value($value->[0]).' and '.$self->quote_value($value->[1])
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
                    push @sets, $attribute.'='.$self->quote_value($constraints->{$key});
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
        $where = ' where '.$self->recurse_where($self->where);
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

    return 'select '.$output.' from '.$self->quote_attribute($self->domain_name).$where.$sort.$limit;
}


no Moose;
__PACKAGE__->meta->make_immutable;
