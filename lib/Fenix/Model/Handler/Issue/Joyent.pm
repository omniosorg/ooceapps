package Fenix::Model::Handler::Issue::Joyent;
use Mojo::Base 'Fenix::Model::Handler::Issue::base', -signatures;

use Mojo::URL;

# attributes
has priority => 5;
has baseurl  => sub { Mojo::URL->new('https://smartos.org') };

# issue should be called first in 'process'.
# It parses the message and checks whether it is the correct handler
# return either a valid issue or undef.
sub issue($self, $msg) {
    return ($msg =~ /\b([A-Z]+-\d+)\b/)[0];
}

sub issueURL($self, $issue) {
    return Mojo::URL->new("/bugview/fulljson/$issue")->base($self->baseurl)->to_abs;
}

sub processIssue($self, $issue, $res) {
    my $data = $res->json->{issue};

    my $url = Mojo::URL->new("/bugview/$issue")->base($self->baseurl)->to_abs;
    for my $comment (@{$data->{fields}->{comment}->{comments}}) {
        my ($commit) = $comment->{body} =~ m!(https://github\.com(?:/[^/]+){2}/commit/[[:xdigit:]]+)!
            or next;

        $url .= " | $commit";
        last;
    }

    return {
        id          => $data->{key},
        subject     => $data->{fields}->{summary},
        url         => $url,
        author      => $data->{fields}->{creator}->{displayName},
        status      => $data->{fields}->{status}->{name},
        assigned_to => $data->{fields}->{assignee}->{displayName},
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
