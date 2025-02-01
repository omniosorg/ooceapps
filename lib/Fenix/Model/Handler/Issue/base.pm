package Fenix::Model::Handler::Issue::base;
use Mojo::Base -base, -signatures;

use Mojo::Exception;
use Mojo::Promise;
use Mojo::UserAgent;
use Mojo::URL;

use Fenix::Utils;

# attributes
has name     => sub($self) { lc ((split /::/, ref $self)[-1]) };
has config   => sub { {} };
has datadir  => sub { Mojo::Exception->throw("ERROR: datadir must be specified on instantiation.\n") };
has chans    => sub { {} };
has baseurl  => sub { Mojo::Exception->throw("ERROR: baseurl is a virtual attribute. Needs to be defined in derived class.\n") };
has priority => sub { Mojo::Exception->throw("ERROR: priority is a virtual attribute. Needs to be defined in derived class.\n") };
has issuestr => sub { 'issue' };
has utils    => sub { Fenix::Utils->new };
has mutemap  => sub { {} };
has ua       => sub {
    my $ua = Mojo::UserAgent->new;

    $ua->max_redirects(8);
    $ua->transactor->name('fenix (OmniOS)');

    return $ua;
};

# issue should be called first in 'process'.
# It parses the message and checks whether it is the correct handler
# return either an array ref of valid URLs or an empty array
sub issues($self, $msg) {
    return [];
}

sub issueURL($self, $issue) {
    return Mojo::URL->new("/issues/$issue")->base($self->baseurl)->to_abs;
}

sub processIssue($self, $issue, $res) {
    return {};
}

sub process_p($self, $issues, $opts = {}) {
    my @urls = map { $self->issueURL($_) } @$issues;

    my $p = Mojo::Promise->new;

    my @reply;
    Mojo::Promise->all_settled(map { $self->ua->get_p($_) } @urls)
        ->then(sub(@promises) {
            for (my $i = 0; $i <= $#promises; $i++) {
                my $promise = $promises[$i];
                my $issue   = $issues->[$i];

                if ($promise->{status} ne 'fulfilled') {
                    push @reply, $self->issuestr . " '$issue' not found...";

                    next;
                }

                my $res = $promise->{value}->[0]->res;

                if ($res->code == 403) {
                    push @reply, $self->issuestr . " '$issue' is not public.";

                    next;
                }

                if (!$res->is_success) {
                    push @reply, $self->issuestr . " '$issue' not found...";

                    next;
                }

                my $data = $self->processIssue($issue, $res);

                # error string returned by the handler
                if (!ref $data) {
                    push @reply, $data;

                    next;
                }

                next if !%$data;

                if (!$opts->{url}) {
                    push @reply, "$data->{id}: $data->{subject} ($data->{status})",
                        @{$data->{url}} ? '↳ ' . join (' | ', @{$data->{url}}) : ();

                    next;
                }

                push @reply, "→ $data->{id}: $data->{subject} ($data->{status})"
                    . (@{$data->{url}} > 1 ? " | $data->{url}->[1]" : '');
            }

            $p->resolve(\@reply);
        });

    return $p;
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
