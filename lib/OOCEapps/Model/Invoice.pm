package OOCEapps::Model::Invoice;
use Mojo::Base 'OOCEapps::Model::base';

use Mojo::SQLite;
use Mojo::File;
use Mojo::Home;
use OOCEapps::Utils;

# attributes
has schema => sub {
    my $sv = OOCEapps::Utils->new;

    return {
    members => {
        lualatex => {
            description => 'path to LuaLaTeX',
            example     => '/opt/ooce/texlive/bin/lualatex',
            validator   => $sv->exe('not an executable'),
        },
        email_from => {
            description => 'email sender address',
            example     => 'patrons@omniosce.org',
            validator   => $sv->regexp(qr/^.*$/, 'expected a string'),
        },
        email_bcc => {
            description => 'email bcc address',
            example     => 'patrons@omniosce.org',
            validator   => $sv->regexp(qr/^.*$/, 'expected a string'),
        },
        key_path => {
            description => 'path to file containing the secret key',
            example     => '/etc/opt/ooce/private/invoice_sec.key',
        },
        create_url => {
            description => 'url prefix for invoice creation requests',
            example     => 'https://apps.omniosce.org/invoice/create',
            validator   => $sv->regexp(qr/^.*$/, 'expected a string'),
        },
    },
    }
};

has sqlite => sub {
    my $self = shift;
    Mojo::SQLite->new->from_filename($self->datadir . '/' . $self->name . '.db');
};

has sec_key => sub {
    my $file = shift->config->{key_path};

    return Mojo::File->new($file)->slurp
        if $file =~ m|^/|;

    return Mojo::Home->new->child('..', 'etc', $file)->slurp;
};

sub register {
    my $self = shift;
    my $r = $self->app->routes;

    $r->options('/' . $self->name . '/request')
        ->to(namespace => $self->controller, action => 'access');

    $r->post('/' . $self->name . '/request')
        ->to(namespace => $self->controller, action => 'requestInvoice');

    $r->get('/' . $self->name . '/create/:req_hash')
        ->to(namespace => $self->controller, action => 'createInvoice');

    $self->sqlite
        ->auto_migrate(1)
        ->migrations->name($self->name)->from_data($self->module, 'invoice.sql');
}

1;

__DATA__

@@ invoice.sql

-- 1 up

CREATE TABLE invoice (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    req_id INTEGER,
    rand TEXT NOT NULL,
    remote_addr TEXT NOT NULL,
    ref TEXT,
    name TEXT NOT NULL,
    company TEXT NOT NULL,
    address TEXT NOT NULL,
    email TEXT NOT NULL,
    currency TEXT NOT NULL,
    amount DECIMAL(10,2) NOT NULL,
    date INTEGER,
    cancelled INTEGER DEFAULT 0
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
