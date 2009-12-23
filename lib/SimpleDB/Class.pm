package SimpleDB::Class;

=head1 NAME

SimpleDB::Class - An Object Relational Mapper (ORM) for the Amazon SimpleDB service.

=head1 SYNOPSIS

 package Library;

 use Moose;
 extends 'SimpleDB::Class';
 
 __PACKAGE__->load_namespaces();

 1;

 package Library::Book;

 use Moose;
 extends 'SimpleDB::Class::Item';

 __PACKAGE__->set_domain_name('book');
 __PACKAGE__->add_attributes(
     title          => { isa => 'Str', default => 'Untitled' },
     publish_date   => { isa => 'Date' },
     edition        => { isa => 'Int', default => 1 },
     isbn           => { isa => 'Str' },
     publisherId    => { isa => 'Str' },
     author         => { isa => 'Str' },
 );
 __PACKAGE__->belongs_to('publisher', 'Library::Publisher', 'publisherId');

 1;

 package Library::Publisher;

 use Moose;
 extends 'SimpleDB::Class::Item';

 __PACKAGE__->set_domain_name('publisher');
 __PACKAGE__->add_attributes({
     name   => { isa => 'Str' },
 });
 __PACKAGE__->has_many('books', 'Library::Book', 'publisherId');

 1;

 use 5.010;
 use Library;
 use DateTime;

 my $library = Library->new(access_key => 'xxx', secret_key => 'yyy', cache_servers=>\@servers );
  
 my $specific_book = $library->domain('book')->find('id goes here');

 my $books = $library->domain('publisher')->books;
 my $books = $library->domain('book')->search({publish_date => DateTime->new(year=>2001)});
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
use SimpleDB::Class::Cache;
use SimpleDB::Class::HTTP;
use SimpleDB::Class::Domain;
use Module::Find;

#--------------------------------------------------------

=head2 new ( params ) 

=head3 params

A hash containing the parameters to pass in to this method.

=head4 access_key

The access key given to you from Amazon when you sign up for the SimpleDB service at this URL: L<http://aws.amazon.com/simpledb/>

=head4 secret_key

The secret access key given to you from Amazon.

=head4 cache_servers

An array reference of cache servers. See L<SimpleDB::Class::Cache> for details.

=cut

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

=head2 http ( )

Returns the L<SimpleDB::Class::HTTP> instance used to connect to the SimpleDB service.

=cut

has http => (
    is              => 'ro',
    lazy            => 1,
    default         => sub { 
                        my $self = shift; 
                        return SimpleDB::Class::HTTP->new(access_key=>$self->access_key, secret_key=>$self->secret_key);
                        },
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

=head2 domain ( moniker )

Returns an instanciated L<SimpleDB::Class::Domain> based upon its L<SimpleDB::Class::Item> classname or its domain name.

=head3 moniker

Can either be the L<SimpleDB::Class::Item> subclass name, or the domain name.

=cut

sub domain {
    my ($self, $moniker) = @_;
    my $class = $self->domain_names->{$moniker};
    $class ||= $moniker;
    my $d = SimpleDB::Class::Domain->new(simpledb=>$self, item_class=>$class);
    return $d;
}

#--------------------------------------------------------

=head2 list_domains ( )

Retrieves the list of domain names from your SimpleDB account and returns them as an array reference.

=cut

sub list_domains {
    my ($self) = @_;
    my $result = $self->http->send_request('ListDomains');
    my $domains = $result->{ListDomainsResult}{DomainName};
    unless (ref $domains eq 'ARRAY') {
        $domains = [$domains];
    }
    return $domains;
}

=head1 PREREQS

This package requires the following modules:

L<XML::Simple>
L<AnyEvent::HTTP>
L<Net::SSLeay>
L<Sub::Name>
L<DateTime>
L<DateTime::Format::Strptime>
L<Moose>
L<MooseX::ClassAttribute>
L<Digest::SHA>
L<URI>
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

Creating subclasses of a domain based upon an attribute in a domain ( so you could have individual dog breed object types all in a dogs domain for example).

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

=item L<SimpleDB::Class::HTTP> - This is our interface to AWS SimpleDB, and can work just fine as a stand alone component if you're looking for a simple way to quickly access SimpleDB.

=item Amazon::SimpleDB (L<http://developer.amazonwebservices.com/connect/entry.jspa?externalID=1136>)

A complete and nicely functional low level library made by Amazon itself.

=item L<Amazon::SimpleDB>

A low level SimpleDB accessor that's in its infancy and may be abandoned, but appears to be pretty functional, and of the same scope as Amazon's own module.

=back

=head1 AUTHOR

JT Smith <jt_at_plainblack_com>

I have to give credit where credit is due: SimpleDB::Class is heavily inspired by L<DBIx::Class> by Matt Trout (and others), and the Amazon::SimpleDB class distributed by Amazon itself (not to be confused with Amazon::SimpleDB written by Timothy Appnel).

=head1 LEGAL

SimpleDB::Class is Copyright 2009 Plain Black Corporation (L<http://www.plainblack.com/>) and is licensed under the same terms as Perl itself.

=cut

no Moose;
__PACKAGE__->meta->make_immutable;
