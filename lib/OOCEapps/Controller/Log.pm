package OOCEapps::Controller::Log;
use Mojo::Base 'OOCEapps::Controller::base';

use Email::Address;
use IRC::Utils qw(parse_user);
use Mojo::File;
use Mojo::JSON qw(decode_json);

# private methods
my $not_found_json = sub {
    return shift->render(json => [], status => 404);
};

# public methods
sub getlog {
    my $c = shift;

    my $chan = $c->stash('chan');
    my $date = $c->stash('date');

    return $c->$not_found_json if !$chan || !$date;

    $chan = "#$chan";
    return $c->$not_found_json if !exists $c->model->chanmap->{$chan};

    my $logf = Mojo::File->new($c->config->{logdir}, $chan, "$date.json");

    return $c->$not_found_json if !-r $logf;

    open my $fh, '<', $logf or return $c->$not_found_json;

    my @log;
    while (<$fh>) {
        my $data = decode_json($_) or next;

        next if !exists $c->model->filtermap->{$data->{command}};

        my $nick = parse_user($data->{prefix}); # scalar context
        my %entry = (
            command => $data->{command},
            nick    => $nick,
            ts      => $data->{ts},
        );

        if ($data->{command} eq 'PRIVMSG') {
            my $msg = $data->{params}->[1] // '';

            for my $addr (Email::Address->parse($msg)) {
                my $oaddr = $addr->address;
                my $naddr = $addr->user . '@...';

                $msg =~ s/\Q$oaddr\E/$naddr/g;
            }

            $entry{message} = $msg;
        }

        push @log, \%entry;
    }

    close $fh;

    $c->render(json => \@log);
}

sub channel {
    my $c = shift;

    $c->render(json => $c->model->index);
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

2021-06-05 had Initial Version

=cut

