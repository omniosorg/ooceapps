package Fenix::Model::Handler::base;
use Mojo::Base -base, -signatures;

use Fenix::Utils;

# attributes
has config   => sub { {} };
has datadir  => sub { Mojo::Exception->throw("ERROR: datadir must be specified on instantiation.\n") };
has chans    => sub { {} };
has utils    => sub { Fenix::Utils->new };
has mutemap  => sub { {} };
has priority => sub { Mojo::Exception->throw("ERROR: priority is a virtual attribute. Needs to be defined in derived class.\n") };
has generic  => 1;
has dm       => 0;

sub process_p($self, $chan, $from, $msg, $mentioned = 0) {
    return undef;
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
