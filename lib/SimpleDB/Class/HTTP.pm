package SimpleDB::Class::HTTP;

=head1 NAME

SimpleDB::Class::HTTP - The network interface to the SimpleDB service.

=head1 SYNOPSIS

 use SimpleDB::Class::HTTP;

 my $http = SimpleDB::Class::HTTP->new(secret_key=>'abc', access_key=>'123');
 my $hashref = $http->send_request('CreateDomain', {DomainName => 'my_new_domain'});

=head1 DESCRIPTION

This class will let you quickly and easily inteface with AWS SimpleDB. It throws exceptions from L<SimpleDB::Class::Exception>, but other than that doesn't rely on any of the other modules in the SimpleDB::Class system, which means it's very light weight. Although we haven't run any benchmarks on the other modules, it should outperform any of the other Perl modules that exist today. 

=head1 METHODS

The following methods are available from this class.

=cut

use Moose;
use Digest::SHA qw(hmac_sha256_base64);
use XML::Simple;
use LWP::UserAgent;
use HTTP::Request;
use Time::HiRes qw(usleep);
use URI::Escape qw(uri_escape_utf8);
use SimpleDB::Class::Exception;
use URI;

#--------------------------------------------------------

=head2 new ( params ) 

=head3 params

A hash containing the parameters to pass in to this method.

=head4 access_key

The access key given to you from Amazon when you sign up for the SimpleDB service at this URL: L<http://aws.amazon.com/simpledb/>

=head4 secret_key

The secret access key given to you from Amazon.

=head4 simpledb_uri

The constructor that SimpleDB::Class will connect to.  Defaults to: 
   
 URI->new('https://sdb.amazonaws.com/')

=cut

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

=head2 simpledb_uri ( )

Returns the L<URI> object passed into the constructor that SimpleDB::Class will connect to.  Defaults to: 

 URI->new('https://sdb.amazonaws.com/')

=cut

has simpledb_uri => (
    is      => 'ro',
    default => sub { URI->new('http://sdb.amazonaws.com/') },
);

#--------------------------------------------------------

=head2 user_agent ( )

Returns the L<LWP::UserAgent> object that is used to connect to SimpleDB. It's cached here so it doesn't have to be created each time. 

=cut

has user_agent => (
    is      => 'ro',
    default => sub { LWP::UserAgent->new(timeout=>30, keep_alive=>1); },
);

#--------------------------------------------------------

=head2 construct_request ( action, [ params ] )

Returns a string that contains the HTTP post data ready to make a request to SimpleDB. Normally this is only called by send_request(), but if you want to debug a SimpleDB interaction, then having access to this method is critical.

=head3 action

The action to perform on SimpleDB. See the "Operations" section of the guide located at L<http://docs.amazonwebservices.com/AmazonSimpleDB/2009-04-15/DeveloperGuide/>.

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
    my $signature = "POST\n".$self->simpledb_uri->host."\n/\n". $post_data;
    $signature = hmac_sha256_base64($signature, $self->secret_key) . '=';
    $post_data .= '&Signature=' . uri_escape_utf8($signature, $encoding_pattern);

    my $request = HTTP::Request->new('POST', $self->simpledb_uri->as_string);
    $request->content_type("application/x-www-form-urlencoded; charset=utf-8");
    $request->content($post_data);

    return $request;
}

#--------------------------------------------------------

=head2 send_request ( action, [ params ] )

Creates a request, and then sends it to SimpleDB. The response is returned as a hash reference of the raw XML document returned by SimpleDB. Automatically attempts 5 cascading retries on connection failure.

Throws SimpleDB::Class::Exception::Response and SimpleDB::Class::Exception::Connection.

=head3 action

See create_request() for details.

=head3 params

See create_request() for details.

=cut

sub send_request {
    my ($self, $action, $params) = @_;
    my $request = $self->construct_request($action, $params);
    # loop til we get a response or throw an exception
    foreach my $retry (1..5) { 

        # make the request
        my $ua = $self->user_agent;
        my $response = $ua->request($request);

        # got a possibly recoverable error, let's retry
        if ($response->code >= 500 && $response->code < 600) {
            if ($retry < 5) {
                usleep((4 ** $retry) * 100_000);
            }
            else {
                warn $response->header('Reason');
                SimpleDB::Class::Exception::Connection->throw(error=>'Exceeded maximum retries.', status_code=>$response->code);
            }
        }

        # not a retry
        else {
            return $self->handle_response($response);
        }
    }
}

#--------------------------------------------------------

=head2 handle_response ( response ) 

Returns a hashref containing the response from SimpleDB.

Throws SimpleDB::Class::Exception::Response.

=head3 response

The L<HTTP::Response> object created by the C<send_request> method.

=cut

sub handle_response {
    my ($self, $response) = @_;
    my $content = eval {XML::Simple::XMLin($response->content, ForceArray => ['Item'])};

    # choked reconstituing the XML, probably because it wasn't XML
    if ($@) {
        SimpleDB::Class::Exception::Response->throw(
            error       => 'Response was garbage. Confirm Net::SSLeay, XML::Parser, and XML::Simple installations.', 
            status_code => $response->code,
            response    => $response,
        );
    }

    # got a valid response
    elsif ($response->is_success) {
        return $content;
    }

    # SimpleDB gave us an error message
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

=head1 LEGAL

SimpleDB::Class is Copyright 2009-2010 Plain Black Corporation (L<http://www.plainblack.com/>) and is licensed under the same terms as Perl itself.

=cut

no Moose;
__PACKAGE__->meta->make_immutable;
