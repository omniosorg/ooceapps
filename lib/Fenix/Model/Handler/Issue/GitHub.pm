package Fenix::Model::Handler::Issue::GitHub;
use Mojo::Base 'Fenix::Model::Handler::Issue::base', -signatures;

use Mojo::URL;

# attributes
has priority => 7;
has baseurl  => sub { Mojo::URL->new('https://github.com') };
has issuestr => sub { 'GitHub commit' };

# issue should be called first in 'process'.
# It parses the message and checks whether it is the correct handler
# return either an array ref of valid URLs or an empty array
sub issues($self, $msg) {
    my $baseurl = $self->baseurl->to_string;
    my $urlre = qr§\b\Q$baseurl\E/((?:[^/]+/){2}commit/[[:xdigit:]]+)$§;
    for ($msg) {
        return ([ /$urlre/g ], { url => 1 }) if /$urlre/;
        return [ m!\b([^/\s]+/[^#\s]+#[[:xdigit:]]+)\b!g ];
    }

    return [];
}

sub issueURL($self, $issue) {
    return Mojo::URL->new("/$issue.patch")->base($self->baseurl)->to_abs
        if $issue =~ m!/commit/!;

    my ($orgrepo, $hash) = split /#/, $issue, 2;

    return Mojo::URL->new("/$orgrepo/commit/$hash.patch")->base($self->baseurl)->to_abs;
}

sub processIssue($self, $issue, $res) {
    my ($orgrepo) = split /#/, $issue, 2;

    # we are only interested in the first 4 lines (the header), drop everything else
    my @data = split /\r?\n/, $res->body, 5;
    pop @data;

    my ($fullhash) = map { /^From\s+([[:xdigit:]]+)/ } @data;
    my $hash = substr $fullhash, 0, 7;

    my ($subject) = map { /^Subject:\s+\[PATCH\]\s+(.+)/ } @data;
    # strip Reviewed by if it occurs on the first commit message line
    $subject =~ s/\s+Reviewed.*$//;

    my ($author) = map { /^From:\s+([^<]+\S)\s+</ } @data;

    return {
        id          => $self->issuestr . " $hash",
        subject     => $subject,
        url         => [ Mojo::URL->new("/$orgrepo/commit/$fullhash")->base($self->baseurl)->to_abs ],
        status      => 'committed',
        author      => $author,
        assigned_to => '',
    };
}

1;

__END__

=head1 COPYRIGHT

Copyright 2025 OmniOS Community Edition (OmniOSce) Association.

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

2025-01-31 had Initial Version

=cut
