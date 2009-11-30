package SimpleDB::Class::ResultSet;

use Moose;
use SimpleDB::Class::Select;

has where => (
    is          => 'ro',
    isa         => 'HashRef',
    required    => 1,
);

has domain => (
    is          => 'ro',
    required    => 1,
);

has result => (
    is          => 'rw',
    isa         => 'HashRef',
    predicate   => 'has_result',
    default     => sub {{}},
    lazy        => 1,
);

has iterator => (
    is          => 'rw',
    default     => 0,
);


#--------------------------------------------------------
sub fetch_result {
    my ($self) = @_;
    my $select = SimpleDB::Class::Select->new(
        domain_name => $self->domain->name,
        where       => $self->where,
    );
    my %params = (SelectExpression => $select->to_sql);

    # if we're fetching and we already have a result, we can assume we're getting the next batch
    if ($self->has_result) { 
        $params{NextToken} = $self->result->{SelectResult}{NextToken};
    }

    my $result = $self->domain->simpledb->send_request('Select', \%params);
    $self->result($result);
    return $result;
}

#--------------------------------------------------------
sub next {
    my ($self) = @_;

    # get the current results
    my $result = ($self->has_result) ? $self->result : $self->fetch_result;
    my $items = (ref $result->{SelectResult}{Item} eq 'ARRAY') ? $result->{SelectResult}{Item} : [$result->{SelectResult}{Item}];
    my $num_items = scalar @{$items};
    return undef unless $num_items > 0;

    # fetch more results if needed
    my $iterator = $self->iterator;
    if ($iterator >= $num_items) {
        if (exists $result->{SelectResult}{NextToken}) {
            $self->iterator(0);
            $iterator = 0;
            $result = $self->fetch_results;
        }
        else {
            return undef;
        }
    }

    # iterate
    my $item = $items->[$iterator];
    return undef unless defined $item;
    $iterator++;
    $self->iterator($iterator);

    # make the item object
    return $self->handle_item($self->domain, $item->{Name}, $item->{Attribute});
}

#--------------------------------------------------------
sub handle_item {
    my ($class, $domain, $id, $list) = @_;
    unless (ref $list eq 'ARRAY') {
        $list = [$list];
    }
    my %attributes;
    foreach my $attribute (@{$list}) {
        if (exists $attributes{$attribute->{Name}}) {
            if (ref $attributes{$attribute->{Name}} ne 'ARRAY') {
                $attributes{$attribute->{Name}} = [$attributes{$attribute->{Name}}];
            }
            push @{$attributes{$attribute->{Name}}}, $attribute->{Value};
        }
        else {
            $attributes{$attribute->{Name}} = $attribute->{Value};
        }
    }
    return SimpleDB::Class::Item->new(domain=>$domain, name=>$id, attributes=>\%attributes);
}

no Moose;
__PACKAGE__->meta->make_immutable;
