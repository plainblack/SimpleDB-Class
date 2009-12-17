package SimpleDB::Class::Cache;


=head1 NAME

Package SimpleDB::Class::Cache

=head1 DESCRIPTION

An API that allows you to cache items to a memcached server.

=head1 SYNOPSIS

 use SimpleDB::Class::Cache;
 
 my $cache = SimpleDB::Class::Cache->new();

 $cache->set($name, $value);
 $cache->set(\@nameSegments, $value);

 my $value = $cache->get($name);
 my ($val1, $val2) = @{$cache->mget([$name1, $name2])};

 $cache->delete($name);

 $cache->flush;

=cut

use Moose;
use SimpleDB::Class::Exception;
use Memcached::libmemcached;
use Storable ();
use Params::Validate qw(:all);
Params::Validate::validation_options( on_fail => sub { 
        my $error = shift; 
        warn "Error in Cache params: ".$error; 
        SimpleDB::Class::Exception::InvalidParam->throw( error => $error );
        } );



=head1 METHODS

These methods are available from this class:

=cut

#-------------------------------------------------------------------

=head2 new ( params ) 

Constructor.

=head3 params

A hash containing configuration params to connect to memcached.

=head4 servers

An array reference of servers (sockets and/or hosts). It should look similar to:

 [
    { host => '127.0.0.1', port=> '11211' },
    { socket  => '/path/to/unix/socket' },
 ]

=cut

#-------------------------------------------------------------------

=head2 servers ( )

Returns the array reference of servers passed into the constructor.

=cut

has 'servers' => (
    is          => 'ro',
    required    => 1,
);

#-------------------------------------------------------------------

=head2 memcached ( )

Returns a L<Memcached::libmemcached> object, which is constructed using the information passed into the constructor.

=cut

has 'memcached' => (
    is  => 'ro',
    lazy    => 1,
    default => sub {
        my $self = shift;
        my $memcached = Memcached::libmemcached::memcached_create();
        foreach my $server (@{$self->servers}) {
            if (exists $server->{socket}) {
                Memcached::libmemcached::memcached_server_add_unix_socket($memcached, $server->{socket}); 
            }
            else {
                Memcached::libmemcached::memcached_server_add($memcached, $server->{host}, $server->{port});
            }
        }
        return $memcached;
    },
);


#-------------------------------------------------------------------

=head2 fix_key ( name )

Returns a key after it's been processed for completeness. Keys cannot have any spaces in them, and this fixes that. However, it means that "foo bar" and "foo_bar" are the same thing.

=head3 name

They key to process.

=cut

sub fix_key {
    my ($self, $key) = @_;
    $key =~ s/\s+/_/g;
    return $key;
}

#-------------------------------------------------------------------

=head2 delete ( name )

Delete a key from the cache.

Throws SimpleDB::Class::Exception::InvalidParam, SimpleDB::Class::Exception::Connection and SimpleDB::Class::Exception.

=head3 name

The key to delete.

=cut

sub delete {
    my $self = shift;
    my ($name) = validate_pos(@_, { type => SCALAR });
    $name = $self->fix_key($name);
    my $memcached = $self->memcached;
    Memcached::libmemcached::memcached_delete($memcached, $name);
    if ($memcached->errstr eq 'SYSTEM ERROR Unknown error: 0') {
        SimpleDB::Class::Exception::Connection->throw(
            error   => "Cannot connect to memcached server."
            );
    }
    elsif ($memcached->errstr eq 'NOT FOUND' ) {
       SimpleDB::Class::Exception::ObjectNotFound->throw(
            error   => "The cache key $name has no value.",
            id      => $name,
            );
    }
    elsif ($memcached->errstr eq 'NO SERVERS DEFINED') {
       SimpleDB::Class::Exception->throw(
            error   => "No memcached servers specified."
            );
    }
    elsif ($memcached->errstr ne 'SUCCESS' # deleted
        && $memcached->errstr ne 'PROTOCOL ERROR' # doesn't exist to delete
        ) {
        SimpleDB::Class::Exception->throw(
            error   => "Couldn't delete $name from cache because ".$memcached->errstr
            );
    }
}

#-------------------------------------------------------------------

=head2 flush ( )

Empties the caching system.

Throws SimpleDB::Class::Exception::Connection and SimpleDB::Class::Exception.

=cut

sub flush {
    my ($self) = @_;
    my $memcached = $self->memcached;
    Memcached::libmemcached::memcached_flush($memcached);
    if ($memcached->errstr eq 'SYSTEM ERROR Unknown error: 0') {
        SimpleDB::Class::Exception::Connection->throw(
            error   => "Cannot connect to memcached server."
        );
    }
    elsif ($memcached->errstr eq 'NO SERVERS DEFINED') {
        SimpleDB::Class::Exception->throw(
            error   => "No memcached servers specified."
        );
    }
    elsif ($memcached->errstr ne 'SUCCESS') {
        SimpleDB::Class::Exception->throw(
            error   => "Couldn't flush cache because ".$memcached->errstr
        );
    }
}

#-------------------------------------------------------------------

=head2 get ( name )

Retrieves a key value from the cache.

Throws SimpleDB::Class::Exception::InvalidObject, SimpleDB::Class::Exception::InvalidParam, SimpleDB::Class::Exception::ObjectNotFound, SimpleDB::Class::Exception::Connection and SimpleDB::Class::Exception.

=head3 name

The key to retrieve.

=cut

sub get {
    my $self = shift;
    my ($name) = validate_pos(@_, { type => SCALAR });
    $name = $self->fix_key($name);
    my $memcached = $self->memcached;
    my $content = Memcached::libmemcached::memcached_get($memcached, $name);
    $content = Storable::thaw($content);
    if ($memcached->errstr eq 'SUCCESS') {
        if (ref $content) {
            return $content;
        }
        else {
            SimpleDB::Class::Exception::InvalidObject->throw(
                error   => "Couldn't thaw value for $name."
                );
        }
    }
    elsif ($memcached->errstr eq 'NOT FOUND' ) {
        SimpleDB::Class::Exception::ObjectNotFound->throw(
            error   => "The cache key $name has no value.",
            id      => $name,
            );
    }
    elsif ($memcached->errstr eq 'NO SERVERS DEFINED') {
        SimpleDB::Class::Exception->throw(
            error   => "No memcached servers specified."
            );
    }
    elsif ($memcached->errstr eq 'SYSTEM ERROR Unknown error: 0') {
        SimpleDB::Class::Exception::Connection->throw(
            error   => "Cannot connect to memcached server."
            );
    }
    SimpleDB::Class::Exception->throw(
        error   => "Couldn't get $name from cache because ".$memcached->errstr
    );
}

#-------------------------------------------------------------------

=head2 mget ( names )

Retrieves multiple values from cache at once, which is much faster than retrieving one at a time. Returns an array reference containing the values in the order they were requested.

Throws SimpleDB::Class::Exception::InvalidParam, SimpleDB::Class::Exception::Connection and SimpleDB::Class::Exception.

=head3 names

An array reference of keys to retrieve.

=cut

sub mget {
    my $self = shift;
    my ($names) = validate_pos(@_, { type => ARRAYREF });
    my @keys = map { $self->fix_key($_) } @{ $names };
    my %result;
    my $memcached = $self->memcached;
    $memcached->mget_into_hashref(\@keys, \%result);
    if ($memcached->errstr eq 'SYSTEM ERROR Unknown error: 0') {
        SimpleDB::Class::Exception::Connection->throw(
            error   => "Cannot connect to memcached server."
            );
    }
    elsif ($memcached->errstr eq 'NO SERVERS DEFINED') {
        SimpleDB::Class::Exception->throw(
            error   => "No memcached servers specified."
            );
    }
    # no other useful status messages are returned
    my @values;
    foreach my $key (@keys) {
        my $content = Storable::thaw($result{$key});
        unless (ref $content) {
            SimpleDB::Class::Exception::InvalidObject->throw(
                id      => $key,
                error   => "Can't thaw object returned from memcache for $key.",
                );
            next;
        }
        push @values, $content;
    }
    return \@values;
}

#-------------------------------------------------------------------

=head2 set ( name, value [, ttl] )

Sets a key value to the cache.

Throws SimpleDB::Class::Exception::InvalidParam, SimpleDB::Class::Exception::Connection, and SimpleDB::Class::Exception.

=head3 name

The name of the key to set.

=head3 value

A hash reference to store.

=head3 ttl

A time in seconds for the cache to exist. When you override default it to 60 seconds.

=cut

sub set {
    my $self = shift;
    my ($name, $value, $ttl) = validate_pos(@_, { type => SCALAR }, { type => HASHREF }, { type => SCALAR | UNDEF, optional => 1 });
    $name = $self->fix_key($name);
    $ttl ||= 60;
    my $frozenValue = Storable::nfreeze($value); 
    my $memcached = $self->memcached;
    Memcached::libmemcached::memcached_set($memcached, $name, $frozenValue, $ttl);
    if ($memcached->errstr eq 'SUCCESS') {
        return $value;
    }
    elsif ($memcached->errstr eq 'SYSTEM ERROR Unknown error: 0') {
        SimpleDB::Class::Exception::Connection->throw(
            error   => "Cannot connect to memcached server."
            );
    }
    elsif ($memcached->errstr eq 'NO SERVERS DEFINED') {
        SimpleDB::Class::Exception->throw(
            error   => "No memcached servers specified."
            );
    }
    SimpleDB::Class::Exception->throw(
        error   => "Couldn't set $name to cache because ".$memcached->errstr
        );
    return $value;
}


=head1 EXCEPTIONS

This class throws a lot of inconvenient, but useful exceptions. If you just want to avoid them you could:

 my $value = eval { $cache->get($key) };
 if (SimpleDB::Class::Exception::ObjectNotFound->caught) {
    $value = $db->fetchValueFromTheDatabase;
 }

The exceptions that can be thrown are:

=head2 SimpleDB::Class::Exception

When an uknown exception happens, or there are no configured memcahed servers in the cacheServers directive in your config file.

=head2 SimpleDB::Class::Exception::Connection

When it can't connect to the memcached servers that are configured.

=head2 SimpleDB::Class::Exception::InvalidParam

When you pass in the wrong arguments.

=head2 SimpleDB::Class::Exception::ObjectNotFound

When you request a cache key that doesn't exist on any configured memcached server.

=head2 SimpleDB::Class::Exception::InvalidObject

When an object can't be thawed from cache due to corruption of some sort.


=head1 AUTHOR

JT Smith <jt_at_plainblack_com>

I have to give credit where credit is due: SimpleDB::Class is heavily inspired by L<DBIx::Class> by Matt Trout (and others), and the Amazon::SimpleDB class distributed by Amazon itself (not to be confused with Amazon::SimpleDB written by Timothy Appnel).

=head1 LEGAL

SimpleDB::Class is Copyright 2009 Plain Black Corporation and is licensed under the same terms as Perl itself.

=cut


no Moose;
__PACKAGE__->meta->make_immutable;

