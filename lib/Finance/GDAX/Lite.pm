package Finance::GDAX::Lite;

# DATE
# VERSION

use 5.010001;
use strict;
use warnings;
use Log::ger;

use Digest::SHA qw(hmac_sha256_base64);
use MIME::Base64 qw(decode_base64);
use Time::HiRes qw(time);

my $url_prefix = "https://api.gdax.com";

sub new {
    my ($class, %args) = @_;

    my $self = {};
    if (my $key = delete $args{key}) {
        $self->{key} = $key;
    }
    if (my $secret = delete $args{secret}) {
        $self->{secret} = $secret;
    }
    if (my $passphrase = delete $args{passphrase}) {
        $self->{passphrase} = $passphrase;
    }
    if (keys %args) {
        die "Unknown argument(s): ".join(", ", sort keys %args);
    }

    require HTTP::Tiny;
    $self->{_http} = HTTP::Tiny->new;

    require JSON::XS;
    $self->{_json} = JSON::XS->new;

    require URI::Encode;
    $self->{_urienc} = URI::Encode->new;

    bless $self, $class;
}

sub _get_json {
    my ($self, $url) = @_;

    log_trace("JSON API request: %s", $url);

    my $res = $self->{_http}->get($url);
    die "Can't retrieve $url: $res->{status} - $res->{reason}"
        unless $res->{success};
    my $decoded;
    eval { $decoded = $self->{_json}->decode($res->{content}) };
    die "Can't decode response from $url: $@" if $@;

    log_trace("JSON API response: %s", $decoded);

    $decoded;
}

sub request {
    my ($self, $method, $request_path, %query_params) = @_;

    $self->{key} or die "Please supply API key in new()";
    $self->{secret} or die "Please supply API secret in new()";
    $self->{passphrase} or die "Please supply API passphrase in new()";

    my $time = time();

    log_trace("API request: %s", \%query_params);

    my $encoded_query_params = $self->{_json}->encode(\%query_params);
    my $what = $time . $method . $request_path . $encoded_query_params;

    my $options = {
        headers => {
            "CB-ACCESS-KEY"  => $self->{key},
            "CB-ACCESS-SIGN" => hmac_sha256_base64($what, decode_base64($self->{secret})),
            "CB-ACCESS-TIMESTAMP" => $time,
            "CB-ACCESS-PASSPHRASE" => $self->{passphrase},
            "Content-Type"   => "application/json",
        },
        content => $encoded_query_params,
    };

    my $url = "$url_prefix$request_path";
    my $res = $self->{_http}->request($method, $url, $options);
    die "Can't retrieve $url: $res->{status} - $res->{reason}"
        unless $res->{success};
    eval {
        $res->{content} = $self->{_json}->decode($res->{content})
            if defined $res->{content};
    };
    die "Can't decode response from $url: $@" if $@;

    log_trace("API response: %s", $res);

    $res;
}

#sub _check_pair {
#    my $pair = shift;
#    $pair =~ /\A(\w{3,5})_(\w{3,5})\z/
#        or die "Invalid pair: must be in the form of 'abc_xyz'";
#}

1;
# ABSTRACT: Client API library for GDAX (lite edition)

=head1 SYNOPSIS

 use Finance::GDAX::Lite;

 my $gdax = Finance::GDAX::Lite->new(
     key        => 'Your API key',
     secret     => 'Your API secret',
     passphrase => 'Your API passphrase',
 );

 $gdax->request(POST => "");


=head1 DESCRIPTION

L<https://gdax.com> is a US cryptocurrency exchange. This module provides a Perl
wrapper for its API.


=head1 METHODS

=head2 new

Usage: new(%args)

Constructor. Known arguments:

=over

=item * key

=item * secret

=item * passphrase

=back


=head2 request

Usage: request($method, $request_path, \%args);


=head1 SEE ALSO

GDAX API Reference, L<https://docs.gdax.com/>
