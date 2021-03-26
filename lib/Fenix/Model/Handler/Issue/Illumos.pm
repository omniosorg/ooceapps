package Fenix::Model::Handler::Issue::Illumos;
use Mojo::Base 'Fenix::Model::Handler::Issue::base', -signatures;

use Mojo::URL;

# constants
my $GERRITID  = 12;
my $GERRITURL = Mojo::URL->new('https://code.illumos.org');

# attributes
has priority => 10;
has baseurl  => sub { Mojo::URL->new('https://www.illumos.org') };

# issue should be called first in 'process'.
# It parses the message and checks whether it is the correct handler
# return either a valid issue or undef.
sub issue($self, $msg) {
    my $baseurl = $self->baseurl->to_string;
    my $urlre   = qr!\b$baseurl/issues/(\d+)(?:\s|$)!;
    for ($msg) {
        /$urlre/ && return ($1, { url => 1 });
        /\b(?:illumos|issue)\b/i && return ($msg =~ /\b(\d{3,})\b/)[0];
        /(?:^|\s)#(\d+)\b/ && return $1;
    }

    return undef;
}

sub issueURL($self, $issue) {
    return Mojo::URL->new("/issues/$issue.json")->base($self->baseurl)->to_abs;
}

sub processIssue($self, $issue, $res) {
    my $data = $res->json->{issue};

    my $url = [ Mojo::URL->new("/issues/$issue")->base($self->baseurl)->to_abs ];
    for my $cf (@{$data->{custom_fields}}) {
        my $cr = $cf->{value};
        next if $cf->{id} != $GERRITID || !$cr;

        push @$url, Mojo::URL->new("/c/illumos-gate/+/$cr")->base($GERRITURL)->to_abs;
    }

    return {
        id       => uc ($data->{tracker}->{name}) . ' ' . $data->{id},
        subject  => $data->{subject},
        url      => $url,
        map { $_ => $data->{$_}->{name} } qw(author status assigned_to),
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
