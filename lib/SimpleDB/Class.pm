package SimpleDB::Class;

our $VERSION = 0.0001;
# Based on Amazon::SimpleDB::Client distributed by Amazon Technologies, Inc and DBIx::Class by Matt Trout and others

use Moose;
use MooseX::ClassAttribute;
use Digest::SHA qw(hmac_sha256_base64);
use XML::Simple;
use LWP::UserAgent;
use HTTP::Request;
use URI::Escape qw(uri_escape_utf8);
use Time::HiRes qw(usleep);
use SimpleDB::Class::Exception;
use Module::Find;

has 'access_key' => (
    is              => 'ro',
    required        => 1,
    documentation   => 'The AWS SimpleDB access key id provided by Amazon.',
);

has 'secret_key' => (
    is              => 'ro',
    required        => 1,
    documentation   => 'The AWS SimpleDB secret access key id provided by Amazon.',
);

class_has 'domain_names' => (
    is      => 'rw',
    default => sub{{}},
);

class_has 'domain_instances' => (
    is      => 'rw',
    default => sub{{}},
);

#--------------------------------------------------------
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
sub determine_domain_class {
    my ($self, $moniker) = @_;
    my $class = $self->domain_names->{$moniker};
    unless ($class) {
        $class = $moniker;
    }
    return $class;
}

#--------------------------------------------------------
sub determine_domain_instance {
    my ($self, $classname) = @_;
    return $self->domain_instances->{$classname};
}

#--------------------------------------------------------
sub domain {
    my ($self, $moniker) = @_;
    my $domain = $self->determine_domain_instance($self->determine_domain_class($moniker));
    $domain->simpledb($self);
    return $domain;
}

#--------------------------------------------------------
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


no Moose;
__PACKAGE__->meta->make_immutable;
