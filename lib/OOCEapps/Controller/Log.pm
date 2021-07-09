package OOCEapps::Controller::Log;
use Mojo::Base 'OOCEapps::Controller::base';

use IRC::Utils qw(parse_user);
use Mojo::File;
use Mojo::JSON qw(decode_json);

# private methods
my $not_found_json = sub {
    return shift->render(json => [], status => 404);
};

# attributes
has emailvalid => sub { Email::Valid->new(-tldcheck => 1) };

# public methods
sub chanlog {
    my $c = shift;

    my $chan  = $c->stash('chan');
    my $start = $c->stash('start_ts');
    my $end   = $start + $c->stash('delta_ts');

    return $c->$not_found_json if !exists $c->model->index->{$chan};

    $c->render_later;

    $c->model->sqlite->db->select_p(
        'log',
        [ qw(nick ts command message message_id) ],
        { 'channel' => $chan, 'ts' => { '-between' => [ $start, $end ] } },
        {
            order_by => [ qw(ts message_id) ],
            limit    => $c->model->config->{max_records}
        }
    )->then(sub {
        $c->render(json => shift->hashes->to_array);
    })->catch(sub {
        $c->$not_found_json;
    })->wait;
}

sub searchlog {
    my $c = shift;

    my %params = map { $_ => $c->param($_) } qw(q channel nick limit page);

    return $c->$not_found_json if !$params{q};
    return $c->$not_found_json if $params{channel} && !exists $c->model->index->{$params{channel}};
    $params{$_} && $params{$_} !~ /^\d+$/ && return $c->$not_found_json for qw(limit page);

    $params{page} ||= 1;
    $params{limit} = $c->model->config->{max_records}
        if !$params{limit} || $params{limit} > $c->model->config->{max_records};

    my $offset = ($params{page} - 1) * $params{limit};

    my %where = (
        fts_message => { 'match', $params{q} },
        public      => { '<>', 0 },
        map { $_ => $params{$_} } grep { $params{$_} } qw(channel nick)
    );

    $c->render_later;

    $c->model->sqlite->db->select_p(
        [ 'log', [ 'fts_message', message_id => 'message_id' ] ],
        [
            qw(ts command channel nick),
            \qq{HIGHLIGHT(fts_message, 1, '\x{1f409}\x{1f404}\x{1f409}', '\x{1f404}\x{1f409}\x{1f404}') AS message},
            qw(log.message_id rank)
        ],
        \%where,
        {
            order_by => [ qw(rank ts log.message_id) ],
            limit    => $params{limit},
            offset   => $offset
        }
    )->then(sub {
        $c->render(json => shift->hashes->grep(sub { exists $c->model->index->{$_->{channel}} })->to_array);
    })->catch(sub {
        $c->$not_found_json;
    })->wait;
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

