package SimpleDB::Class;

=head1 NAME

SimpleDB::Class - An Object Relational Mapper (ORM) for the Amazon SimpleDB service.

=head1 SYNOPSIS

 package Library;

 use Moose;
 extends 'SimpleDB::Class';
 
 __PACKAGE__->load_namespaces();

 1;

 package Library::Books;

 use Moose;
 extends 'SimpleDB::Class::Domain';

 __PACKAGE__->set_name('books');
 __PACKAGE__->add_attributes({
     title          => { isa => 'Str', default => 'Untitled' },
     publish_date   => { isa => 'Int' },
     isbn           => { isa => 'Str' },
     publisherId    => { isa => 'Str' },
     author         => { isa => 'Str' },
 });
 __PACKAGE__->belongs_to('publisher', 'Library::Publishers', 'publisherId');

 1;

 package Library::Publishers;

 use Moose;
 extends 'SimpleDB::Class::Domain';

 __PACKAGE__->set_name('publishers');
 __PACKAGE__->add_attributes({
     name   => { isa => 'Str' },
 });
 __PACKAGE__->has_many('books', 'Library::Books', 'publisherId');

 1;

 use 5.010;
 use Library;
 use DateTime;

 my $library = Library->new(access_key => 'xxx', secret_key => 'yyy', cache_servers=>\@servers );
  
 my $specific_book = $library->domain('books')->find('id goes here');

 my $books = $library->domain('publishers')->books;
 my $books = $library->domain('books')->search({publish_date => DateTime->new(year=>2001)});
 while (my $book = $books->next) {
    say $book->title;
 }

=head1 DESCRIPTION

SimpleDB::Class gives you a way to persist your objects in Amazon's SimpleDB service search them easily. It hides the mess of web services, sudo SQL, and XML document formats that you'd normally need to deal with to use the service, and gives you a tight clean Perl API to access it.

On top of being a simple to use ORM that functions in a manner similar to L<DBIx::Class>, SimpleDB::Class has some other niceties that make dealing with SimpleDB easier:

=over

=item *

It uses memcached to cache objects locally so that most of the time you don't have to care that SimpleDB is eventually consistent. This also speeds up many requests. See Eventual Consistency below for details.

=item *

It has cascading retries, which means it automatically attepts to retry failed requests (you have to plan for failure on the net). 

=item *

It automatically formats dates and integers for sortability in SimpleDB. 

=item *

It automatically casts date fields as DateTime objects. 

=item *

It uses L<Moose> for everything, which makes it easy to use Moose's introspection features or method insertion features. 

=item *

It automatically generates UUID based ItemNames (unique IDs) if you don't want to supply an ID yourself. 

=item *

It automatically deals with the fact that you might have some attributes in your L<SimpleDB::Class::Item>s that aren't specified in your L<SimpleDB::Class::Domain> subclasses, and creates accessors and mutators for them on the fly at retrieval time. 

=item *

L<SimpleDB::Class::ResultSet>s automatically fetch additional items from SimpleDB if a next token is provided.

=back

=head2 Eventual Consistency

SimpleDB is eventually consistent, which means that if you do a write, and then read directly after the write you may not get what you just wrote. L<SimpleDB::Class> gets around this problem for the post part because it caches all L<SimpleDB::Class::Item>s in memcached. That is to say that if an object can be read from cache, it will be. The one area where this falls short are some methods in L<SimpleDB::Class::Domain> that perform searches on the database which look up items based upon their attributes rather than based upon id. Even in those cases, once an object is located we try to pull it from cache rather than using the data SimpleDB gave us, simply because the cache may be more current. However, a search result may return too few (inserts pending) or too many (deletes pending) results in L<SimpleDB::Class::ResultSet>, or it may return an object which no longer fits certain criteria that you just searched for (updates pending). As long as you're aware of it, and write your programs accordingly, there shouldn't be a problem.

Does all this mean that this module makes SimpleDB as ACID compliant as a traditional RDBMS? No it does not. There are still no locks on domains (think tables), or items (think rows). So you probably shouldn't be storing sensitive financial transactions in this. We just provide an easy to use API that will allow you to more easily and a little more safely take advantage of Amazon's excellent SimpleDB service for things like storing logs, metadata, and game data.

For more information about eventual consistency visit L<http://en.wikipedia.org/wiki/Eventual_consistency> or the eventual consistency section of the Amazon SimpleDB Developer's Guide at L<http://docs.amazonwebservices.com/AmazonSimpleDB/2009-04-15/DeveloperGuide/EventualConsistencySummary.html>.

=head1 METHODS

The following methods are available from this class.

=cut

use Moose;
use MooseX::ClassAttribute;
use Digest::SHA qw(hmac_sha256_base64);
use XML::Simple;
use LWP::UserAgent;
use HTTP::Request;
use URI::Escape qw(uri_escape_utf8);
use Time::HiRes qw(usleep);
use SimpleDB::Class::Exception;
use SimpleDB::Class::Cache;
use Module::Find;

#--------------------------------------------------------

=head2 new ( params ) 

=head3 params

A hash containing the parameters to pass in to this method.

=head4 access_key

The access key given to you from Amazon when you sign up for the SimpleDB service at this URL: L<http://aws.amazon.com/simpledb/>

=head4 secret_key

The secret access key given to you from Amazon.

=cut

#--------------------------------------------------------

=head2 cache_servers ( )

Returns the cache server array reference passed into the constructor.

=cut

has cache_servers => (
    is          => 'ro',
    required    => 1,
);

#--------------------------------------------------------

=head2 cache ( )

Returns a reference to the L<SimpleDB::Class::Cache> instance.

=cut

has cache => (
    is      => 'ro',
    lazy    => 1,
    default => sub {
        my $self = shift;
        return SimpleDB::Class::Cache->new(servers=>$self->cache_servers);
    },
);

#--------------------------------------------------------

=head2 access_key ( )

Returns the access key passed to the constructor.

=cut

has 'access_key' => (
    is              => 'ro',
    required        => 1,
    documentation   => 'The AWS SimpleDB access key id provided by Amazon.',
);

#--------------------------------------------------------

=head2 secret_key ( )

Returns the secret key passed to the constructor.

=cut

has 'secret_key' => (
    is              => 'ro',
    required        => 1,
    documentation   => 'The AWS SimpleDB secret access key id provided by Amazon.',
);

#--------------------------------------------------------

=head2 domain_names ( )

Class method. Returns a hashref of the domain names and class names registered from subclassing L<SimpleDB::Class::Domain> and calling set_name. 

=cut

class_has 'domain_names' => (
    is      => 'rw',
    default => sub{{}},
);

#--------------------------------------------------------

=head2 domain_classes ( [ list ] )

Class method. Returns a hashref of the domain class names and instances registered from subclassing L<SimpleDB::Class::Domain> and calling set_name. 

=cut

class_has 'domain_instances' => (
    is      => 'rw',
    default => sub{{}},
);

#--------------------------------------------------------

=head2 load_namespaces ( [ namespace ] )

Class method. Loads all the modules in the current namespace, so if you subclass SimpleDB::Class with a package called Library (as in the example provided), then everything in the Library namespace would be loaded automatically. Should be called to load all the modules you subclass, so you don't have to manually use each of them.

=head3 namespace

Specify a specific namespace like Library::SimpleDB if you don't want everything in the Library namespace to be loaded.

=cut

sub load_namespaces {
    my ($class, $namespace) = @_;
    $namespace ||= $class; # if no namespace is set
    useall $namespace;
}

#--------------------------------------------------------
sub _add_domain {
    my ($class, $name, $object) = @_;
    my $classname = ref $object;
    my $names = $class->domain_names;
    $names->{$name} = $classname;
    __PACKAGE__->domain_names($names);
    my $instances = $class->domain_instances;
    $instances->{$classname} = $object;
    __PACKAGE__->domain_instances($instances);
    return $names;
}

#--------------------------------------------------------

=head2 determine_domain_class ( moniker ) 

Given a domain name or class name, returns the class name associated with it.

=head2 moniker

A class name or a domain name that is a subclass of L<SimpleDB::Class::Domain>. In the above example Library::Books or books would both return Library::Books.

=cut

sub determine_domain_class {
    my ($self, $moniker) = @_;
    my $class = $self->domain_names->{$moniker};
    unless ($class) {
        $class = $moniker;
    }
    return $class;
}

#--------------------------------------------------------

=head2 determine_domain_instance ( classname )

Returns an instanciated L<SimpleDB::Class::Domain> based upon it's class name. 

=head3 classname

The classname to fetch an instance for. In the above example, Library::Books or Library::Publishers would both work.

=cut

sub determine_domain_instance {
    my ($self, $classname) = @_;
    my $domain = $self->domain_instances->{$classname};
    $domain->simpledb($self);
    return $domain;
}

#--------------------------------------------------------

=head2 domain ( moniker )

Returns an instanciated L<SimpleDB::Class::Domain> based upon it's classname or domain name.

=head3 moniker

See determine_domain_class() for details.

=cut

sub domain {
    my ($self, $moniker) = @_;
    return $self->determine_domain_instance($self->determine_domain_class($moniker));
}

#--------------------------------------------------------

=head2 construct_request ( action, [ params ] )

Returns a L<HTTP::Request> object ready to make a request to SimpleDB. Normally this is only called by send_request(), but if you want to debug a SimpleDB interaction, then having access to this method is critical.

=head3 action

The action to perform on SimpleDB. See the "Operations" section of the guide located at L<<a href="http://docs.amazonwebservices.com/AmazonSimpleDB/2009-04-15/DeveloperGuide/">http://docs.amazonwebservices.com/AmazonSimpleDB/2009-04-15/DeveloperGuide/</a>>.

=head3 params

Any extra prameters required by the operation. The normal parameters of Action, AWSAccessKeyId, Version, Timestamp, SignatureMethod, SignatureVersion, and Signature are all automatically provided by this method.

=cut

sub construct_request {
    my ($self, $action, $params) = @_;
    my $encoding_pattern = "^A-Za-z0-9\-_.~";

    # add required parameters
    $params->{'Action'}           = $action;
    $params->{'AWSAccessKeyId'}   = $self->access_key;
    $params->{'Version'}          = '2009-04-15';
    $params->{'Timestamp'}        = sprintf("%04d-%02d-%02dT%02d:%02d:%02d.000Z", sub { ($_[5]+1900, $_[4]+1, $_[3], $_[2], $_[1], $_[0]) }->(gmtime(time)));
    $params->{'SignatureMethod'}  = 'HmacSHA256';
    $params->{'SignatureVersion'} = 2;

    # construct post data
    my $post_data;
    foreach my $name (sort {$a cmp $b} keys %{$params}) {
        $post_data .= $name . '=' . uri_escape_utf8($params->{$name}, $encoding_pattern) . '&';
    }
    chop $post_data;

    # sign the post data
    my $signature = "POST\nsdb.amazonaws.com\n/\n". $post_data;
    $signature = hmac_sha256_base64($signature, $self->secret_key) . '=';
    $post_data .= '&Signature=' . uri_escape_utf8($signature, $encoding_pattern);

    # construct the request
    my $request = HTTP::Request->new('POST', 'https://sdb.amazonaws.com/');
    $request->content_type("application/x-www-form-urlencoded; charset=utf-8");
    $request->content($post_data);

    return $request;
}

#--------------------------------------------------------

=head2 list_domains ( )

Retrieves the list of domain names from your SimpleDB account and returns them as an array reference.

=cut

sub list_domains {
    my ($self) = @_;
    my $result = $self->send_request('ListDomains');
    my $domains = $result->{ListDomainsResult}{DomainName};
    unless (ref $domains eq 'ARRAY') {
        $domains = [$domains];
    }
    return $domains;
}

#--------------------------------------------------------

=head2 send_request ( action, [ params ] )

Creates a request, and then sends it to SimpleDB. The response is returned as a hash reference of the raw XML document returned by SimpleDB. Automatically attempts 5 cascading retries on connection failure.

=head3 action

See create_request() for details.

=head3 params

See create_request() for details.

=cut

sub send_request {
    my ($self, $action, $params) = @_;
    my $retries = 0;
    while (1) { # loop til we get a response or throw an exception
        my $ua = LWP::UserAgent->new;
        my $response = $ua->request($self->construct_request($action, $params));
        my $content = eval { XML::Simple::XMLin($response->content)};
        if ($@) {
            SimpleDB::Class::Exception::Response->throw(
                error       => 'Response was garbage.', 
                status_code => $response->code,
                response    => $response,
            );
        }
        elsif ($response->is_success) {
            return $content;
        }
        elsif ($response->code == 500 || $response->code == 503) {
            if ($retries < 5) {
                usleep((4 ** $retries) * 100000);
            }
            else {
                SimpleDB::Class::Exception::Connection->throw(error=>'Exceeded maximum retries.', status_code=>$response->code);
            }
        }
        else {
            SimpleDB::Class::Exception::Response->throw(
                error       => $content->{Errors}{Error}{Message},
                status_code => $response->code,
                error_code  => $content->{Errors}{Error}{Code},
                box_usage   => $content->{Errors}{Error}{BoxUsage},
                request_id  => $content->{RequestID},
                response    => $response,
            );
        }
    }
}

=head1 PREREQS

This package requires the following modules:

L<XML::Simple>
L<LWP>
L<Crypt::SSLeay>
L<DateTime>
L<DateTime::Format::Strptime>
L<Moose>
L<MooseX::ClassAttribute>
L<Digest::SHA>
L<URI>
L<Time::HiRes>
L<Module::Find>
L<UUID::Tiny>
L<Exception::Class>
L<Memcached::libmemcached>

=head1 TODO

This is an experimental class, and as such the API will likely change frequently over the next few releases. Still left to figure out:

=over

=item *

Sub-searches from relationships.

=item *

Make puts and deletes asynchronous, since SimpleDB is eventually consistent, there's no reason to wait around for these operations to complete.

=item *

Creating subclasses of a domain based upon an attribute in a domain ( so you could have individuall dog breed object types all in a dogs domain for example).

=item *

Creating multi-domain objects ( so you can put each country's data into it's own domain, but still search all country-oriented data at once).

=item *

More exception handling.

=item *

More tests.

=item *

All the other stuff I forgot about or didn't know when I designed this thing.

=back

=head1 SUPPORT

=over

=item Repository

L<http://github.com/plainblack/SimpleDB-Class>

=item Bug Reports

L<http://rt.cpan.org/Public/Dist/Display.html?Name=SimpleDB-Class>

=back

=head1 SEE ALSO

There are other packages you can use to access SimpleDB. I chose not to use them because I wanted something a bit more robust that would allow me to easily map objects to SimpleDB Domain Items. If you're looking for a low level SimpleDB accessor, then you should check out these:

=over

=item Amazon::SimpleDB (L<http://developer.amazonwebservices.com/connect/entry.jspa?externalID=1136>)

A complete and nicely functional low level library made by Amazon itself.

=item L<Amazon::SimpleDB>

A low level SimpleDB accessor that's in its infancy and may be abandoned, but appears to be pretty functional, and of the same scope as Amazon's own module.

=back

=head1 AUTHOR

JT Smith <jt_at_plainblack_com>

I have to give credit where credit is due: SimpleDB::Class is heavily inspired by L<DBIx::Class> by Matt Trout (and others), and the Amazon::SimpleDB class distributed by Amazon itself (not to be confused with Amazon::SimpleDB written by Timothy Appnel).

=head1 LEGAL

SimpleDB::Class is Copyright 2009 Plain Black Corporation and is licensed under the same terms as Perl itself.

=cut

no Moose;
__PACKAGE__->meta->make_immutable;
