package OOCEapps::Model::Invoice;
use Mojo::Base 'OOCEapps::Model::base';

use Mojo::SQLite;
use Email::MIME;
use Email::Sender::Simple;
use Time::Piece;
use OOCEapps::Utils;

# attributes
has schema => sub {
    my $sv = OOCEapps::Utils->new;

    return {
    members => {
        lualatex => {
            description => 'path to LuaLaTeX',
            example     => '/opt/ooce/texlive/bin/lualatex',
            validator   => $sv->executable,
        },
        email_to => {
            description => 'email recipient address',
            example     => 'patrons@omniosce.org',
            validator   => $sv->regexp(qr/^.*$/, 'expected a string'),
        },
    },
    }
};

has sqlite => sub {
    my $self = shift;
    Mojo::SQLite->new->from_filename($self->datadir . '/' . $self->name . '.db');
};

sub register {
    my $self = shift;

    my $r = $self->app->routes;
    $r->any('/' . $self->name . '/create')
        ->to(namespace => $self->controller, action => 'createInvoice');

    $self->sqlite
        ->auto_migrate(1)
        ->migrations->name($self->name)->from_data($self->module, 'invoice.sql');
}

sub sendMail {
    my $self = shift;
    my $to   = shift;
    my $id   = shift;
    my $mail = shift;
    my $pdf  = shift;

    my $filename = localtime->strftime('%Y%m%d') . "_invoice-$id.pdf";
    my $mimeparts = [
        Email::MIME->create(
            attributes => {
                content_type => 'text/plain',
                charset      => 'US-ASCII',
            },
            body => $mail,
        ),
        Email::MIME->create(
            attributes => {
                filename     => $filename,
                content_type => 'application/pdf',
                encoding     => 'base64',
                name         => $filename,
            },
            body => $pdf,
        ),
    ];

    my $message = Email::MIME->create(
        header => [
            From    => $to,
            To      => $to,
            Subject => "Invoice $id created",
        ],
        parts => $mimeparts,
    );

    Email::Sender::Simple->send($message);
}

1;

__DATA__

@@ invoice.sql

-- 1 up

CREATE TABLE invoice (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    invnr TEXT NOT NULL,
    ref TEXT,
    name TEXT NOT NULL,
    company TEXT NOT NULL,
    address TEXT NOT NULL,
    email TEXT NOT NULL,
    currency TEXT NOT NULL,
    amount DECIMAL(10,2) NOT NULL,
    date INTEGER
);

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

S<Dominik Hassler E<lt>hadfl@omniosce.orgE<gt>>
S<Tobias Oetiker E<lt>tobi@oetiker.chE<gt>>

=head1 HISTORY

2017-09-11 had Initial Version

=cut
