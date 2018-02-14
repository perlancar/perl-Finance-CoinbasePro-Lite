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

    my $time = $ENV{FINANCE_GDAX_LITE_DEBUG_TIME} // sprintf "%.3f", time();

    log_trace("API request [%s]: %s %s %s",
              $time, $method, $request_path, \%query_params);

    my $url = "$url_prefix$request_path";

    my $body;
    my $encoded_body = '';
    if ($method eq 'POST') {
        $body = $encoded_body = $self->{_json}->encode(\%query_params);
    } else {
        if (keys %query_params) {
            my $qs = '?' . join(
                "&",
                map { $self->{_urienc}->encode($_ // ''). "=" .
                          $self->{_urienc}->encode($query_params{$_} // '') }
                    sort keys(%query_params),
            );
            $url .= $qs;
            $encoded_body = $qs;
        }
    }

    my $what = $time . $method . $request_path . $encoded_body;
    my $signature = hmac_sha256_base64($what, decode_base64($self->{secret}));
    while (length($signature) % 4) { $signature .= '=' }

    my $options = {
        headers => {
            "CB-ACCESS-KEY"  => $self->{key},
            "CB-ACCESS-SIGN" => $signature,
            "CB-ACCESS-TIMESTAMP" => $time,
            "CB-ACCESS-PASSPHRASE" => $self->{passphrase},
            "Content-Type"   => "application/json",
            "Accept"         => "application/json",
        },
        (content => $body ) x !!defined($body),
    };

    my $res = $self->{_http}->request($method, $url, $options);
    die "Can't retrieve $url: $res->{status} - $res->{reason}"
        unless $res->{success};
    eval {
        $res->{content} = $self->{_json}->decode($res->{content})
            if defined $res->{content};
    };
    die "Can't decode response from $url: $@" if $@;

    log_trace("API response [%s]: %s", $time, $res);

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
