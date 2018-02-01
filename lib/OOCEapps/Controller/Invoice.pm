package OOCEapps::Controller::Invoice;
use Mojo::Base 'OOCEapps::Controller::base';

use File::Temp;
use Mojo::File;
use Mojo::Util qw(encode);
use Crypt::Ed25519;
use OOCEapps::Utils;

has sqlite  => sub { shift->model->sqlite };
has sec_key => sub { shift->model->sec_key };
has fields  => sub { [ qw(name company address currency amount email ref) ] };

#private methods
my $remote_addr = sub {
    my $c = shift;

    return $c->req->headers->header('X-Real-IP')
        || $c->req->headers->header('X-Forwarded-For')
        || $c->tx->remote_address;
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

sub requestInvoice {
    my $c = shift;

    my $headers = $c->res->headers;
    $headers->header('Access-Control-Allow-Origin' => '*');

    my $data = $c->req->json
        or return $c->render(text => 'bad input', code => 500);

    $data->{req_id} = time . sprintf('%04d', int (rand (9999) + 1));
    my $req_url = OOCEapps::Utils::pack($data, $c->sec_key);

    $c->stash(
        url         => $c->config->{create_url} . "/$req_url",
        remote_addr => $c->$remote_addr,
        map { $_ => $data->{$_} } @{$c->fields},
    );

    my ($mail, $mail_html) = map {
        encode 'UTF-8',
            $c->render_to_string('invoice/mail/invoice_requested', format => $_)
    } qw(txt html);

    OOCEapps::Utils::sendMail($_, $c->config->{email_from},
        'Your OmniOS Support pro-forma invoice request',
        {
            body => $mail,
        },
        [
            {
                content_type => 'text/html',
                disposition  => 'inline',
                encoding     => 'quoted-printable',
                body         => $mail_html,
            },
        ],
        {
            'Content-Type' => 'multipart/alternative',
        }
    ) for ($data->{email}, $c->config->{email_bcc});

    $c->render(json => { status => 'ok' });
}

sub createInvoice {
    my $c = shift;

    my $req_data = OOCEapps::Utils::unpack($c->stash('req_hash'),
        Crypt::Ed25519::eddsa_public_key($c->sec_key), 24 * 3600);

    my %data;
    eval {
        if (my $d = $c->sqlite->db->select(
            'invoice', '*', { req_id => $req_data->{req_id} })->hash) {
            %data = (
                id          => $d->{id},
                date        => $d->{date},
                rand        => $d->{rand},
                remote_addr => $d->{remote_addr},
                map { $_ => $d->{$_} } @{$c->fields},
            );
        }
        else {
            %data = (
                rand => sprintf('%04d', int (rand (9999) + 1)),
                date => time,
                map { $_ => $req_data->{$_} } @{$c->fields},
            );

            my $res = $c->sqlite->db->insert('invoice', {
                date        => $data{date},
                rand        => $data{rand},
                remote_addr => $c->$remote_addr,
                req_id      => $req_data->{req_id},
                %data
            });
            $data{id} = $res->last_insert_id if $res;
        }
    };

    if ($@){
        if ($@ =~ m{execute failed:\s(.+?) at /}){
            return $c->render(text => $1, code => 500);
        }
        return $c->render(text => 'bad input', code => 500);
    }

    my $invnr = "$data{id}.$data{rand}";
    $c->stash(
        AssetPath => $c->app->home->rel_file('share/invoice')->to_string,
        InvoiceId => $invnr,
        %data
    );
    my $tex = $c->render_to_string(template => 'invoice/invoice', format => 'tex');

    Mojo::IOLoop->subprocess(
        sub {
            my $subprocess = shift;

            my $tmpDir = File::Temp->newdir();
            chdir $tmpDir;
            my $texFile = Mojo::File->new('invoice.tex');
            $texFile->spurt(encode 'UTF-8', $tex);

            open my $latex, '-|', $c->config->{lualatex}, 'invoice';
            my $latexOut = do { local $/; <$latex> };
            close $latex;

            my $output = 'invoice.pdf';
            die $latexOut if !-e $output || -z $output;

            my $pdf = Mojo::File->new($output)->slurp;
            chdir '/';
            return $pdf;
        },
        sub {
            my ($subprocess, $err, $pdf) = @_;

            if (!$pdf){
                $c->log->error("Subprocess error: $err");
                return $c->render(text => "<pre>ERROR: $err</pre>", staus => 500);
            }

            my $mail = encode 'UTF-8',
                $c->render_to_string(template => 'invoice/mail/invoice_created', format => 'txt');

            my $filename = "$data{date}_invoice-$invnr.pdf";
            OOCEapps::Utils::sendMail($c->config->{email_bcc}, $c->config->{email_from},
                "Invoice $invnr created",
                {
                    body => $mail,
                },
                [
                    {
                        filename     => $filename,
                        content_type => 'application/pdf',
                        name         => $filename,
                        body         => $pdf,
                    }
                ],
            );

            $c->res->headers->content_disposition("inline; filename=invoice-$invnr.pdf;");
            return $c->render(data => $pdf, format => 'pdf');
        }
    );

    $c->inactivity_timeout(60);
    $c->render_later;
}

1;

__END__

=head1 COPYRIGHT

Copyright 2018 OmniOS Community Edition (OmniOSce) Association.

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

S<Tobias Oetiker E<lt>tobi@oetiker.chE<gt>>

=head1 HISTORY

2017-12-03 to Initial Version

=cut
