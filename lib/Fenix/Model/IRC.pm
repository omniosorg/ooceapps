package Fenix::Model::IRC;
use Mojo::Base 'Mojo::IRC', -signatures;

use Time::Piece;

use Mojo::Exception;
use Mojo::File;
use Mojo::JSON qw(encode_json);

# attributes
has config  => sub { {} };
has datadir => sub { Mojo::Exception->throw("ERROR: datadir must be specified on instantiation.\n") };
has chans   => sub {
    return {
        map {
            $_->{name} => {
                log         => $_->{log}         eq 'on' ? 1 : 0,
                interactive => $_->{interactive} eq 'on' ? 1 : 0,
            }
        } @{shift->config->{CHANS}}
    }
};

# private methods
my $connect;
$connect = sub($self) {
    $self->connect(sub($irc, $err) {
        if ($err) {
            Mojo::IOLoop->timer(10 => sub { $self->$connect });
            return warn $err;
        }
        $irc->write(JOIN => $_) for keys %{$self->chans};
    });
};

# constructor
sub new($self, %args) {
    my $config = $args{config};

    return $self->SUPER::new(
        %args,
        tls => $config->{tls} eq 'on' ? {} : undef,
        map { $_ => $config->{$_} } grep { $config->{$_} } qw(nick user pass server)
    );
}

# public methods
sub start($self) {
    # logging
    $self->on(message => sub($irc, $msg) {
        my $chan = $msg->{params}->[0];

        return if !($msg->{event} eq 'privmsg'
            || $chan eq $irc->nick || $self->chans->{$chan}->{log});

        my $time   = gmtime;
        my $day    = $time->ymd;
        $msg->{ts} = $time->epoch;

        my $log = Mojo::File->new($self->datadir, $chan, "$day.json");
        $log->dirname->make_path;

        open my $fh, '>>', $log
            or Mojo::Exception->throw("ERROR: cannot open file '$log': $!\n");
        say $fh encode_json($msg);
        close $fh;
    });

    # interactive
    $self->on(irc_privmsg => sub($irc, $msg) {
        my $nick = $irc->nick;
        my $chan = $msg->{params}->[0];
        my $text = $msg->{params}->[1];

        return if $text !~ /\b$nick(?![a-z\d_\-\[\]\\^{}|`])/i
            || !$self->chans->{$chan}->{interactive};

        # just say 'hi' for now
        $irc->write(PRIVMSG => $chan => ":hi");
    });

    # error handling
    $self->on(error => sub($irc, $msg) {
        Mojo::Exception->throw($msg);
    });

    # try to reconnect if the connection has been closed
    $self->on(close => sub($irc) {
        warn "disconnected, trying to recnnect in 10 seconds\n";
        Mojo::IOLoop->timer(10 => sub { $self->$connect });
    });

    # connect to the configured channels
    $self->$connect;
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
