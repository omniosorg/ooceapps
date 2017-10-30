package OOCEapps::Controller::Patron;
use Mojo::Base 'OOCEapps::Controller::base';
use Digest::SHA qw(hmac_sha256_hex);

# attributes
has secKey => sub { shift->config->{secKey} };
has pubKey => sub { shift->config->{secKey} };

has log  => sub { shift->app->log };
has data => sub {
    shift->req->json;
};

has model => sub {
    shift->app->model->{Patron};
};

sub access {
    my $c = shift;

    my $headers = $c->res->headers;

    $headers->header('Access-Control-Allow-Origin'  => '*');
    $headers->header('Access-Control-Allow-Methods' => 'POST');
    $headers->header('Access-Control-Max-Age'       => 3600);
    $headers->header('Access-Control-Allow-Headers' => 'Content-Type');
    $c->render(text => '');
}

sub subscribe {
    my $c = shift;
    my $headers = $c->res->headers;
    $headers->header('Access-Control-Allow-Origin'  => '*');
    my $data = $c->data;
    eval {
        if (not $data->{token}){
            die ['No Shopping without token'];
        }
        my $cust = $c->model->createCustomer($data->{token});
        if ($data->{period} eq 'once') {
            $c->model->createCharge(
                $cust->{id},
                int($data->{amount}),
                $data->{currency},
            );
        }
        else {
            $c->model->createSubscription(
                $cust->{id},
                $data->{period}.'_'.$data->{currency},
                $data->{amount}
            );
        }
    };
    if ($@){
        if (ref $@ eq 'ARRAY'){
            $c->log->error($@->[0]);
            $c->render(json=>{status=>'error'});
        }
        else {
            die $@;
        }
    }
    $c->render(json=>{status=>'ok'})

}


sub webhook {
    my $c = shift;
    eval {
        if (not $c->model->checkStripeSignature($c->req)){
            $c->log->error("invalid chatter: ".$c->req->to_string);
            die ['invalid signature'];
        }
        my $data = $c->data;
        $c->log->debug('handle '.$data->{type});
        if (my $cust_id = ( $c->data->{data}{object}{customer}
            ||   $c->data->{data}{object}{source}{customer}) ){
            $data->{data}{customer} = $c->model->getCustomer($cust_id);
            $data->{data}{subscriptions} = $c->model->getSubscriptions($cust_id);
            my $subKey = $c->model->getSubKey($data->{data}{subscriptions}{data}[0]{id});
            $data->{cancelUrl} = $c->model->config->{cancelUrl}.'/'.$subKey if $subKey;
            $c->stash(stripeData=>$data);
            if (my $mail = $c->render_to_string(
                template => 'patron/mail/'.$data->{type},
                format => 'txt')){
                $c->model->sendMail($data->{data}{customer}{email},$mail->to_string);
            }
        }
        else {
            $c->log->debug('Webhook Unhandled:'.$c->app->dumper($data));
        }
    };
    if ($@){
        if (ref $@ eq 'ARRAY'){
            $c->log->error($@->[0]);
            return $c->render(json=>{status=>'error'});
        }
        else {
            $c->log->error("ERROR: sending mail: $@");
            $c->log->error("Available Data: ".$c->app->dumper($c->data));
        }
    }
    $c->render(status=>200,text=>'ok');
};

sub cancelSubscriptionForm {
    my $c = shift;
    $c->render('patron/cancelSubscriptionForm');
}

sub cancelSubscription {
    my $c = shift;
    $c->log->debug($c->param('subKey'));
    my ($t,$sub,$sig) = split /-/, $c->param('subKey');
    if (hmac_sha256_hex($t.'-'.$sub, $c->model->mailSec) ne $sig){
        return $c->render(text=>'Invalid Subscription Key',status=>400);
    }
    eval {
        # for now we are ignoring the age of the keys
        # such that unsubscribing is ALWAYS possible
        $c->stash( stripeData => $c->model->cancelSubscription($sub));
    };
    if ($@){
        if (ref $@ eq 'ARRAY'){
            $c->log->error($@->[0]);
            return $c->render(text=>"Sorry there was an error canceling your subscription. Please get in touch with patron\@omniosce.org");
        }
        else {
            die $@;
        }
    }
    $c->render('patron/cancelSubscription');
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

=cut
