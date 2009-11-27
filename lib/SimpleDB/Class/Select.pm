package SimpleDB::Class::Select;

use Moose;

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

has 'sort' => (
    is              => 'ro',
    predicate       => 'has_sort',
);

has 'limit' => (
    is              => 'ro',
    predicate       => 'has_limit',
);

#--------------------------------------------------------
sub escape {
    my ($self, $string) = @_;
    $string =~ s/\\/\\\\/g;
    $string =~ s/'/\'/g;
    return "'".$string."'";
}

#--------------------------------------------------------
sub to_sql {
    my ($self) = @_;

    # output
    my $output = $self->output;
    if (ref $output eq 'ARRAY') {
        $output = join(', ', @{$output});
    }

    # where
    my $where;
    if ($self->has_where) {
        my @clauses;
        my $constraints = $self->where;
        foreach my $name (keys %{$constraints}) {
            push @clauses, $name.'='.$self->escape($constraints->{$name})
        }
        $where = ' where '.join(' and ', @clauses);
    }

    # sort
    my $sort;
    if ($self->has_sort) {
        my $by = $self->sort;
        my $direction = 'asc';
        if (ref $by eq 'ARRAY') {
            ($by, $direction) = @{$by};
        }
        $sort = ' order by '.$by.'() '.$direction;
    }

    # limit
    my $limit;
    if ($self->has_limit) {
        $limit = ' limit '.$self->limit;
    }

    return 'select '.$output.' from '.$self->domain->name.$where.$sort.$limit;
}


no Moose;
__PACKAGE__->meta->make_immutable;
