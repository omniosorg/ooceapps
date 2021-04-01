package Fenix::Model::Handler::Issue::Gerrit;
use Mojo::Base 'Fenix::Model::Handler::Issue::base', -signatures;

use Mojo::JSON qw(decode_json);
use Mojo::URL;

# constants
my $ILLUMOSURL = Mojo::URL->new('https://www.illumos.org');

# attributes
has priority => 8;
has baseurl  => sub { Mojo::URL->new('https://code.illumos.org') };

# issue should be called first in 'process'.
# It parses the message and checks whether it is the correct handler
# return either a valid issue or undef.
sub issue($self, $msg) {
    my $baseurl = $self->baseurl->to_string;
    my $urlre   = qr!\b$baseurl/c/illumos-gate/\+/(\d+)\b!;
    for ($msg) {
        /$urlre/ && return ($1, { url => 1 });
        /\bcode\b/i && return ($msg =~ /\b(\d{2,})\b/)[0];
    }

    return undef;
}

sub issueURL($self, $issue) {
    return Mojo::URL->new("/changes/$issue/detail")->base($self->baseurl)->to_abs;
}

sub processIssue($self, $issue, $res) {
    my $body = $res->body;
    $body =~ s/^\)\]\}'//;
    my $data = decode_json $body;

    my $url = [ Mojo::URL->new("/c/illumos-gate/+/$issue")->base($self->baseurl)->to_abs ];

    $data->{subject} =~ /^(\d+)/
        && push @$url, Mojo::URL->new("/issues/$1")->base($ILLUMOSURL)->to_abs;

    $data->{subject} =~ s/\s+(?:Reviewed|Portions\s+contributed)\s+by.+$//i;
    return {
        id       => "CODE REVIEW $issue",
        subject  => $data->{subject},
        url      => $url,
        status   => $data->{status},
        map { $_ => $data->{owner}->{name} } qw(author assigned_to),
    };
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
