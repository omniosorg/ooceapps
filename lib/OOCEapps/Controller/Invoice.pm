package OOCEapps::Controller::Invoice;
use Mojo::Base 'OOCEapps::Controller::base';
use File::Temp;
use Mojo::File;
use Mojo::Util qw(encode html_unescape);

has sqlite => sub { shift->model->sqlite };
has fields => sub { [ qw(name company address currency amount email ref) ] };

sub createInvoice {
    my $c = shift;
    my $data = $c->req->json
        or return $c->render(text => 'bad input', code => 500);

    my $invnr = sprintf('%010d', int (rand (9999999999) + 1));
    my %data  = map { $_ => html_unescape $data->{$_} } @{$c->fields};

    my $result = eval {
        $c->sqlite->db->insert('invoice', {
            date  => time,
            invnr => $invnr,
            %data
        });
    };

    if ($@){
        if ($@ =~ m{execute failed:\s(.+?) at /}){
            return $c->render(text => $1, code => 500);
        }
        return $c->render(text => 'bad input', code => 500);
    }

    $c->stash(
        AssetPath => $c->app->home->rel_file('share/invoice')->to_string,
        InvoiceId => $invnr,
        %data
    );
    my $tex = $c->render_to_string(template => 'invoice/invoice', format => 'tex');

    my $subprocess = Mojo::IOLoop::Subprocess->new;
    $subprocess->run(
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

            $c->stash(%data);
            my $mail = encode 'UTF-8',
                $c->render_to_string(template => 'invoice/mail/invoice_created', format => 'txt');
            $c->model->sendMail($c->config->{email_to}, $invnr, $mail, $pdf);

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
