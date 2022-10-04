package Fenix::Model::Handler::Issue::OpenSolaris;
use Mojo::Base 'Fenix::Model::Handler::Issue::base', -signatures;

use Mojo::URL;

# attributes
has priority => 9;
has baseurl  => sub { Mojo::URL->new('https://illumos.org') };
has issuestr => sub { 'OpenSolaris issue' };

# issue should be called first in 'process'.
# It parses the message and checks whether it is the correct handler
# return either a valid issue or undef.
sub issue($self, $msg) {
    my $baseurl = $self->baseurl->to_string;
    my $urlre   = qr§\b\Q$baseurl\E/opensolaris/bugdb/bug\.html#!(\d{7})\b§;
    for ($msg) {
        /$urlre/ && return ($1, { url => 1 });
        /\b(\d{7})\b/ && return $1;
    }

    return undef;
}

sub issueURL($self, $issue) {
    return Mojo::URL->new("/opensolaris/bugdb/$issue.json")->base($self->baseurl)->to_abs;
}

sub processIssue($self, $issue, $res) {
    my $data = $res->json;

    return {
        id       => $self->issuestr . " $issue",
        subject  => $data->{synopsis},
        url      => [ Mojo::URL->new("/opensolaris/bugdb/bug.html#!$issue")->base($self->baseurl)->to_abs ],
        status   => $data->{state},
        map { $_ => $data->{responsible_engineer} } qw(author assigned_to),
    };
}

1;

__END__

=head1 COPYRIGHT

Copyright 2022 OmniOS Community Edition (OmniOSce) Association.

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

2022-10-04 had Initial Version

=cut
