package Fenix::Model::IRC;
use Mojo::Base 'Mojo::IRC', -signatures;

use Time::Piece;

use Mojo::Exception;
use Mojo::File;
use Mojo::JSON qw(encode_json);
use IRC::Utils qw(eq_irc);

use Fenix::Utils;

# constants
my $MODPREFIX = join '::', (split /::/, __PACKAGE__)[0 .. 1], 'Handler';

# attributes
has config  => sub { {} };
has datadir => sub { Mojo::Exception->throw("ERROR: datadir must be specified on instantiation.\n") };
has utils   => sub { Fenix::Utils->new };
has mutemap => sub { {} };
has chans   => sub($self) {
    return {
        map {
            my $chan = $_;
            $chan->{name} => { map { $_ => $chan->{$_} eq 'on' } qw(log interactive generic) }
        } @{$self->config->{CHANS}}
    }
};
has handler => sub($self) {
    return $self->utils->loadModules(
        $MODPREFIX,
        config  => $self->config,
        datadir => $self->datadir,
        chans   => $self->chans,
        utils   => $self->utils,
        mutemap => $self->mutemap,
    );
};
has handlers => sub($self) {
    return [
        sort {
            $self->handler->{$a}->priority <=> $self->handler->{$b}->priority
            || $a cmp $b
        } keys %{$self->handler}
    ]
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

my $log = sub($self, $msg) {
    my $chan = $msg->{params}->[0];

    return if !($msg->{event} eq 'privmsg'
        || eq_irc($chan, $self->nick) || $self->chans->{$chan}->{log});

    my $time   = gmtime;
    my $day    = $time->ymd;
    $msg->{ts} = $time->epoch;

    my $logdir = eq_irc($chan, $self->nick) ? $self->utils->from($msg->{prefix}) : $chan;

    my $logf = Mojo::File->new($self->datadir, $logdir, "$day.json");
    $logf->dirname->make_path;

    open my $fh, '>>', $logf
        or Mojo::Exception->throw("ERROR: cannot open file '$logf': $!\n");
    say $fh encode_json($msg);
    close $fh;
};

my $sendMsg = sub($self, $to, $msg) {
    $self->write(PRIVMSG => $to => ":$msg" => sub($irc, $err) {
        return warn $err if $err;

        # log own messages
        my $nick = $self->nick;
        $self->$log({
            event => 'privmsg',
            %{$self->parser->parse(":$nick PRIVMSG $to :$msg")},
        });
    });
};

my $process = sub($self, $chan, $from, $text) {
    for my $hd (@{$self->handlers}) {
        next if !eq_irc($chan, $from) && $self->handler->{$hd}->generic
            && !$self->chans->{$chan}->{generic};

        my $reply = $self->handler->{$hd}->process($chan, $from, $text);

        next if !@$reply;

        $self->$sendMsg($self->handler->{$hd}->dm ? $from : $chan, $_)
            for @$reply;

        last;
    }
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
    $self->on(message => sub($irc, $msg) { $self->$log($msg) });

    # interactive
    $self->on(irc_privmsg => sub($irc, $msg) {
        my $nick = $irc->nick;
        my $chan = $msg->{params}->[0];
        my $text = $msg->{params}->[1];
        my $from = $self->utils->from($msg->{prefix});

        # handle DMs
        return $self->$process($from, $from, $text) if eq_irc($nick, $chan);

        # in case the nick has changed.
        my $cfgNick = $self->config->{nick};
        my $nickRE  = eq_irc($nick, $cfgNick) ? qr/$nick/ : qr/$nick|$cfgNick/;
        return if $text !~ /(?:^|[^a-z\d_\-\[\]\\^{}|`])$nickRE(?:[^a-z\d_\-\[\]\\^{}|`]|$)/i
            || !$self->chans->{$chan}->{interactive};

        $self->$process($chan, $from, $text);

        # register the user to the mutemap (will be used by generic handlers)
        $self->utils->muted(\$self->mutemap->{user}, $from);
    });

    # error handling
    $self->on(error => sub($irc, $msg) {
        warn $msg;
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
