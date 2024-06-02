package Fenix::Model::Handler::Issue::IPD;
use Mojo::Base 'Fenix::Model::Handler::Issue::base', -signatures;

use Mojo::URL;

# constants
my $GITHUB = Mojo::URL->new('https://github.com');

# attributes
has priority => 4;
has baseurl  => sub { Mojo::URL->new('https://raw.githubusercontent.com') };
has issuestr => sub { 'IPD' };

# issue should be called first in 'process'.
# It parses the message and checks whether it is the correct handler
# return either a valid issue or undef.
sub issues($self, $msg) {
    my $baseurl = $GITHUB->to_string;
    my $urlre   = qr!\b\Q$baseurl\E/illumos/ipd/\S+/ipd/0+(\d+)/README\.md\b!i;
    for ($msg) {
        return ([ /$urlre/g ], { url => 1 }) if /$urlre/;
        return [ /\bIPD[-\s]*(\d{1,3})\b/ig ];
    }

    return [];
}

sub issueURL($self, $issue) {
    return Mojo::URL->new("/illumos/ipd/master/README.md")->base($self->baseurl)->to_abs;
}

sub processIssue($self, $issue, $res) {
    for (split /[\r\n]+/, $res->body) {
        my ($status, $desc, $url)
            = /^\s*\|\s*([^\s|]+)\s*\|\s*\[\s*IPD\s+$issue\s+([^\]]+)\]\(([^\)]+)/ or next;

        $url =~ s!^\.?/!!;
        return {
            id          => "IPD $issue",
            subject     => $desc,
            url         => [ Mojo::URL->new("/illumos/ipd/tree/master/$url")->base($GITHUB)->to_abs ],
            author      => '',
            status      => $status,
            assigned_to => '',
        };
    }

    return "IPD '$issue' not found...";
}

1;

__END__

=head1 COPYRIGHT

Copyright 2024 OmniOS Community Edition (OmniOSce) Association.

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
