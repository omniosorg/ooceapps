package Fenix::Model::Handler::Issue::base;
use Mojo::Base -base, -signatures;

use Mojo::Exception;
use Mojo::UserAgent;
use Mojo::URL;

use Fenix::Utils;

# attributes
has config  => sub { {} };
has datadir => sub { Mojo::Exception->throw("ERROR: datadir must be specified on instantiation.\n") };
has chans   => sub { {} };
has baseurl => sub { Mojo::Exception->throw("ERROR: baseurl is a virtual attribute. Needs to be defined in derived class.\n") };
has utils   => sub { Fenix::Utils->new };
has mutemap => sub { {} };
has ua      => sub { Mojo::UserAgent->new };

# issue should be called first in 'process'.
# It parses the message and checks whether it is the correct handler
# return either a valid issue or undef.
sub issue($self, $msg) {
    return undef;
}

sub issueURL($self, $issue) {
    return Mojo::URL->new("/issues/$issue")->base($self->baseurl)->to_abs;
}

sub processIssue($self, $issue, $res) {
    return {};
}

sub getIssue($self, $issue) {
    my $url = $self->issueURL($issue);
    my $res = $self->ua->get($url)->result;

    return [ "issue '$issue' is not public." ] if $res->code == 403;
    return [ "issue '$issue' not found..." ] if !$res->is_success;

    my $data = $self->processIssue($issue, $res);
    return [] if !%$data;

    return [
        "$data->{id}: $data->{subject} ($data->{status})",
        "↳ $data->{url}",
    ];
}

sub process($self, $chan, $from, $msg) {
    my $issue = $self->issue($msg);

    return [] if !defined $issue
        || $self->utils->muted(\$self->mutemap->{issue}->{$chan}, $issue);

    return $self->getIssue($issue);
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
