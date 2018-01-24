package OOCEapps::Model::Invoice;

use Mojo::Base 'OOCEapps::Model::base';

use OOCEapps::Utils;

sub register {
    my $self = shift;
    my $r = $self->app->routes;
    $r->any('/' . $self->name.'/create')
        ->to(namespace =>  $self->controller, action => 'createInvoice');

    $self->app->sqlite
        ->auto_migrate(1)
        ->migrations->name('Invoice')->from_data(__PACKAGE__,'invoice.sql');
}

1;
__DATA__

@@ invoice.sql

-- 1 up

CREATE TABLE invoice (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    company TEXT NOT NULL,
    address TEXT NOT NULL,
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
2017-10-29 to Full stripe

=cut
