package Fenix::Model::Handler::Hi;
use Mojo::Base 'Fenix::Model::Handler::base', -signatures;

use Time::Piece;

# default handler, lowest priority.
#if we get mentioned but don't know what to do we
# are at least polite and say 'Hi'.
has priority => 9999;

sub process($self, $chan, $from, $msg, $mentioned = 0) {
    return [] if !$mentioned || $self->utils->muted(\$self->mutemap->{user}, $from);

    # little friday is special
    return [ gmtime->day_of_week == 4 ? "Happy little Friday $from!" : "Hi $from" ];
}

1;

__END__

=head1 COPYRIGHT

Copyright 2021 OmniOS Community Edition (OmniOSce) Association.

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

S<Dominik Hassler E<lt>hadfl@omnios.orgE<gt>>

=head1 HISTORY

2021-01-08 had Initial Version

=cut
