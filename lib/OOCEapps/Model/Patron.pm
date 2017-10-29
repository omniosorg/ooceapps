package OOCEapps::Model::Patron;

use Mojo::Base 'OOCEapps::Model::base';

use OOCEapps::Utils;
use Mojo::File;
use Mojo::Template;
use Mojo::JSON qw(true);
use Digest::SHA qw(hmac_sha256_hex);
use Email::Sender::Simple qw(sendmail);
use Email::Simple;
use Email::Simple::Creator;

# attributes
has schema  => sub {
    my $sv = OOCEapps::Utils->new;
    return {
        members => {
            'keyPath' => {
                description => 'path to file containing the stripe public and secret keys on 2 lines',
                example     => '/etc/opt/ooce/private/stripe.key',
            },
            'cancelUrl' => {
                description => 'url prefix for cancelation requests',
                example     => 'https://apps.omniosce.org/patron/cancle',
            },
            'emailFrom' => {
                description => 'email sender address',
                example     => 'patronage@omniosce.org',
            },
            'emailBcc' => {
                description => 'email bcc address',
                example     => 'patronage@omniosce.org',
            },
            'subCurrencies' => {
                description => 'list of currencies',
                example     => '["chf","usd","gbp"]',
            },
            'subIntervals' => {
                description => 'list of subscription intervals',
                example     => '["week","month","year"]',
            },
            'subDescription' => {
                description => 'statement descriptor',
                example     => 'Weekly OmniOSce Pat.',
            }
        },
    }
};

has ua => sub { shift->app->ua };

has plans => sub {
    my $self = shift;
    my $cfg = $self->config;
    my $intervals = $cfg->{subIntervals};
    my $currencies = $cfg->{subCurrencies};
    my %plans;
    for my $interval (@$intervals){
        for my $currency (@$currencies){
            my $plan = $interval.'_'.$currency;
            $plans{$plan} = 1;
            my ($err,$json) = $self->callStripe('GET','plans/'.$plan);
            if ($json->{error} and $json->{error}{type} eq 'invalid_request_error'){
                my ($err,$json) = $self->callStripe('POST','plans',{
                    name => ucfirst($interval).'ly '.uc($currency),
                    interval =>  $interval,
                    currency => $currency,
                    statement_descriptor => $cfg->{subDescripton},
                    amount => 100,
                    id => $plan
                });
                $self->log->info("created subscription plan '$plan'");
            }
        }
    }
    return \%plans;
};

has 'pubKey';
has 'secret';
has 'hookSec';
has 'mailSec';

sub register {
    my $self = shift;
    my $r = $self->app->routes;

    $r->options('/' . $self->name.'/subscribe')
        ->to(namespace =>  $self->controller, action => 'access');

    $r->post('/' . $self->name.'/subscribe')
        ->to(namespace => $self->controller, action => 'subscribe');

    $r->get('/' . $self->name.'/cancel/:subKey')
            ->to(namespace => $self->controller, action => 'cancelSubscription');

    $r->post('/' . $self->name.'/webhook')
            ->to(namespace => $self->controller, action => 'webhook');

    my $file = $self->config->{keyPath};
    if ($file =~ m{^[^/]}){
        $file = Mojo::Home->new->child('..','etc',$file);
    }
    else {
        $file = Mojo::Path->new($file);
    }

    my ($pubKey, $secret, $hook, $mail) = split /[\n\r]/, $file->slurp;
    $self->pubKey($pubKey);
    $self->secret($secret);
    $self->hookSec($hook);
    $self->mailSec($mail);
}

sub createCustomer {
    my ($self,$token) = @_;
    my ($err,$json) = $self->callStripe('POST','customers',{
        source => $token->{id},
        email => $token->{email},
        name => $token->{name}
    });
    if ($err){
        die [$err];
    }
    return $json;
}
sub createCharge {
    my ($self,$customer,$amount,$currency) = @_;
    my ($err,$json) = $self->callStripe('POST','charges',{
        customer => $customer,
        amount => $amount * 100,
        currency => $currency,
        description => $self->config->{subDescription}.' One Time',
        statement_descriptor => $self->config->{subDescription},
        capture => 'true',
    });
    if ($err){
        die [$err];
    }
    return $json;
}

sub getCustomer {
    my ($self,$id) = @_;
    my ($err,$json) = $self->callStripe('GET','customers/'.$id);
    if ($err){
        die [$err];
    }
    return $json;
}

sub getSubscriptions {
    my ($self,$id) = @_;
    my ($err,$json) = $self->callStripe('GET','subscriptions',{
        customer => $id
    });
    if ($err){
        die [$err];
    }
    return $json;
}

sub createSubscription {
    my ($self,$customer,$plan,$amount) = @_;
    if (not $self->plans->{$plan}){
        die ["Plan $plan does not exist"];
    }
    my ($err,$json) = $self->callStripe('POST','subscriptions',{
        customer => $customer,
        'items[0][plan]' => $plan,
        'items[0][quantity]' => $amount
    });
    if ($err){
        die [$err];
    }
    return $json;
}

sub cancelSubscription {
    my $self = shift;
    my $id = shift;
    my ($err,$json) = $self->callStripe('DELETE','subscriptions'.'/sub_'.$id);
    if ($err){
        if ($err =~ /No such subscription/i){
            return {
                message => 'Subscription is already canceled'
            };
        }
        die [$err];
    }
    return $json;
}

sub sendMail {
    my $self = shift;
    my $recipient = shift;
    my $mail = shift;
    my $sender = $self->config->{emailFrom};
    my $email = Email::Simple->new(<<MESSAGE_END);
From: $sender
To: $recipient
$mail
MESSAGE_END
    sendmail($email, { to => $self->config->{emailBcc}});
    sendmail($email);
}

sub callStripe {
    my $self = shift;
    my $method = shift;
    my $ep = shift;
    my $args = shift;
    my $cb = shift;
    my $ua = $self->ua;
    my $tx = $ua->build_tx(
        $method => 'https://'.$self->secret.':@api.stripe.com/v1/'.$ep => {} =>
        form => $args);
    my $proc;
    if ($cb){
        Mojo::IOLoop->delay(sub {
                $ua->start($tx,shift->begin);
            },
            sub {
                $cb->($self->_tx_to_res($_[1]));
            }
        );
    }
    else {
        $ua->start($tx);
        return $self->_tx_to_res($tx);
    }
}

# stolen from https://github.com/jhthorsen/mojolicious-plugin-stripepayment/blob/master/lib/Mojolicious/Plugin/StripePayment.pm

sub _tx_to_res {
  my ($self, $tx) = @_;
  my $error = $tx->error     || {};
  my $json  = $tx->res->json || {};
  my $err   = '';
  if ($error->{code} or $json->{error}) {
    my $message = $json->{error}{message} || $json->{error}{type} || $error->{message};
    my $type    = $json->{error}{param}   || $json->{error}{code} || $error->{code};
    $err = sprintf '%s: %s', $type || 'Unknown', $message || 'Could not find any error message.';
  }

  return $err, $json;
}

sub checkStripeSignature {
    my ($self,$req) = @_;
    my $sig = { map { split /=/ } split /\s*,\s*/, ( $req->headers->header('Stripe-Signature') // '') };
    return $sig->{v1} eq hmac_sha256_hex($sig->{t}.'.'.$req->body, $self->hookSec);
}

sub getSubKey {
    my ($self,$sub) = @_;
    if ($sub and $sub =~ s/^sub_//){
        my $t = time;
        return $t.'-'.$sub.'-'.hmac_sha256_hex($t.'-'.$sub,$self->mailSec);
    }
    return undef;
}

1;

__END__

=head1 COPYRIGHT

Copyright 2017 OmniOS Community Edition (OmniOSce) Association.

=head1 LICENSE

This program is free software: you can redistribute it and/or modify it
under the terms of the GNU General Public License as published by the Free
Software Foundation, either version 3 of the License, or (at your option)
any later version.
This program is distributed in the hope that it will be useful, but WITHOUT
ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for
more details.
You should have received a copy of the GNU General Public License along with
this program. If not, see L<http://www.gnu.org/licenses/>.

=head1 AUTHOR

S<Dominik Hassler E<lt>hadfl@omniosce.orgE<gt>>
S<Tobias Oetiker E<lt>tobi@oetiker.chE<gt>>

=head1 HISTORY

2017-09-11 had Initial Version
2017-10-29 to Full stripe

=cut
