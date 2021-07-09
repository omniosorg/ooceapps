package OOCEapps::Model::Log;
use Mojo::Base 'OOCEapps::Model::base';

use Mojo::File;
use Mojo::SQLite;
use Time::Seconds qw(ONE_DAY);

# attributes
has schema => sub {
    my $sv = shift->utils;

    return {
        dbpath      => {
            description => 'path to SQLite log database',
            example     => '/var/opt/ooce/ooceapps/fenix/irclog.db',
            validator   => $sv->file('<', 'cannot open database'),
        },
        max_records => {
            description => 'maximum number of records to return',
            default     => 5000,
            example     => '1234',
            validator   => $sv->regexp(qr/^\d+$/, 'expected a numeric input'),
        },
    };
};
has index  => sub {
    my $self = shift;

    return {
        map {
            my $chan = $_;
            $chan->{channel} => { map { $_ => $chan->{$_} } qw(begin topic) }
        }
        @{$self->sqlite->db->select(
            [ 'channel', [ 'message', channel_id => 'channel_id' ] ],
            [ 'channel', 'topic', \'MIN(ts) AS begin' ],
            { public   => { '<>', 0 } },
            { group_by => [ qw(channel topic) ] }
        )->hashes->to_array}
    };
};
has sqlite => sub {
    my $self = shift;

    my $sql = Mojo::SQLite->new->from_filename($self->config->{dbpath});

    $sql->on(connection => sub {
        my ($sql, $dbh) = @_;

        $dbh->do("PRAGMA $_ = ON;") for qw(foreign_keys query_only);
    });

    return $sql;
};


# public methods
sub register {
    my $self = shift;

    my $r = $self->app->routes;

    # APIv1
    my $apiv1 = $r->any('/' . $self->name . '/api/v1')
        ->to(controller => $self->controller);
    $apiv1->get('/channel')->to(action => 'channel');
    $apiv1->get('/channel/:chan/:start_ts/:delta_ts' => [ start_ts => qr/\d+/, delta_ts => qr/\d+/ ])
        ->to(action => 'chanlog', delta_ts => ONE_DAY);
    $apiv1->get('/search')->to(action => 'searchlog');
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

