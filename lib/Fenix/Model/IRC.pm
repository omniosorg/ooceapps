package Fenix::Model::IRC;
use Mojo::Base 'Mojo::IRC', -signatures;

use Time::Piece;

use Mojo::Exception;
use Mojo::File;
use Mojo::JSON qw(encode_json);
use Mojo::Promise;
use Mojo::SQLite;
use IRC::Utils qw(eq_irc is_valid_chan_name is_valid_nick_name);
use Scalar::Util qw(blessed);

use Fenix::Utils;

# constants
my $MODPREFIX = join '::', (split /::/, __PACKAGE__)[0 .. 1], 'Handler';

# private static methods
my $stripChanPrefix = sub($chan) {
    $chan =~ s/^#//;

    return $chan;
};

my $stripOpPrefix = sub($nick) {
    $nick =~ s/^[@+]//;

    return $nick;
};

# attributes
has config  => sub { {} };
has datadir => sub { Mojo::Exception->throw("ERROR: datadir must be specified on instantiation.\n") };
has utils   => sub { Fenix::Utils->new };
has mutemap => sub { {} };
has chans   => sub($self) {
    return {
        map {
            my $chan = $_;
            $chan->{name} => { map { $_ => $chan->{$_} eq 'on' } qw(log public interactive generic) }
        } @{$self->config->{CHANS}}
    }
};
has users   => sub { {} };
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
has sqlite   => sub($self) {
    my $sql = Mojo::SQLite->new->from_filename(
        Mojo::File->new($self->datadir, 'irclog.db'));

    $sql->on(connection => sub ($sql, $dbh) {
        $dbh->do('PRAGMA foreign_keys = ON;');
    });

    return $sql;
};

# private methods
my $connect;
$connect = sub($self) {
    # reset online users on connect
    $self->users({});

    $self->connect(sub($irc, $err) {
        if ($err) {
            Mojo::IOLoop->timer(10 => sub { $self->$connect });
            return warn $err;
        }
        $irc->write(JOIN => $_) for keys %{$self->chans};
    });
};

my $logToFile = sub($self, $dir, $file, $msg) {
    my $logf = Mojo::File->new($self->datadir, $dir, $file);
    $logf->dirname->make_path;

    # delete 'event' since that information is covered in 'command'
    delete $msg->{event};

    open my $fh, '>>', $logf
        or Mojo::Exception->throw("ERROR: cannot open file '$logf': $!\n");
    say $fh encode_json($msg);
    close $fh;
};

my $log = sub($self, $msg) {
    my $time   = gmtime;
    my $day    = $time->ymd;
    $msg->{ts} = $time->epoch;
    my $nick   = $self->utils->from($msg->{prefix});

    for ($msg->{command}) {
        /^(RPL_)?TOPIC$/ && do {
            shift @{$msg->{params}} if $1; # for RPL_TOPIC the first param is the own nick

            my $chan = $msg->{params}->[0];

            return if !$self->chans->{$chan}->{log};

            my $logf = Mojo::File->new($self->datadir, $chan, '__currtopic');
            $logf->dirname->make_path;

            $logf->spurt($msg->{params}->[1]);

            $chan = $stripChanPrefix->($chan);

            $self->sqlite->db->update('channel', { topic => $msg->{params}->[1] },
                { channel => $chan });

            return;
        };
        /^RPL_NAMREPLY$/ && do {
            my $chan = $msg->{params}->[2];

            return if !$self->chans->{$chan}->{log};

            # there can be multiple RPL_NAMREPLY messages;
            # don't map but add users individually
            $self->users->{$chan}->{$_} = undef
                for map { $stripOpPrefix->($_) } split /\s+/, $msg->{params}->[3];

            return;
        };
        /^NICK$/ && do {
            my $nnick = $msg->{params}->[0];

            for my $chan (keys %{$self->users}) {
                next if !exists $self->users->{$chan}->{$nick};

                delete $self->users->{$chan}->{$nick};
                $self->users->{$chan}->{$nnick} = undef;

                $self->$logToFile($chan, "$day.json", $msg);

                $chan = $stripChanPrefix->($chan);

                $self->sqlite->db->insert('log', {
                    channel => $chan,
                    nick    => $nick,
                    message => $nnick,
                    map { $_ => $msg->{$_} } qw(ts command)
                });
            }

            # update new nick in case its capitalisation changed
            $self->sqlite->db->update('nick', { nick => $nnick }, { nick => $nnick });

            return;
        };
        /^QUIT$/ && do {
            for my $chan (keys %{$self->users}) {
                next if !exists $self->users->{$chan}->{$nick};

                delete $self->users->{$chan}->{$nick};

                $self->$logToFile($chan, "$day.json", $msg);

                $chan = $stripChanPrefix->($chan);

                $self->sqlite->db->insert('log', {
                    channel => $chan,
                    nick    => $nick,
                    map { $_ => $msg->{$_} } qw(ts command)
                });
            }

            return;
        };
        /^JOIN$/ && do {
            my $chan = $msg->{params}->[0];

            return if !$self->chans->{$chan}->{log};

            $self->users->{$chan}->{$nick} = undef;

            # update nick in case its capitalisation changed
            $self->sqlite->db->update('nick', { nick => $nick }, { nick => $nick });

            last;
        };
        /^PART$/ && do {
            my $chan = $msg->{params}->[0];

            delete $self->users->{$chan}->{$nick};

            last;
        };
    }

    my $chan   = $msg->{params}->[0];
    my $ischan = is_valid_chan_name($chan);

    return if ($ischan && !$self->chans->{$chan}->{log})
        || (!$ischan && $msg->{command} ne 'PRIVMSG');

    my $logdir = eq_irc($chan, $self->nick) ? $nick : $chan;

    $self->$logToFile($logdir, "$day.json", $msg);

    # only log channel messages to SQLite
    return if !$ischan;

    $chan = $stripChanPrefix->($chan);

    $msg->{params}->[1] = $self->utils->spoofEmail($msg->{params}->[1])
        if $msg->{command} eq 'PRIVMSG';

    $self->sqlite->db->insert('log', {
        channel => $chan,
        nick    => $nick,
        message => $msg->{params}->[1],
        map { $_ => $msg->{$_} } qw(ts command)
    });
};

my $process_p = sub($self, $chan, $from, $text, $mentioned = 0) {
    my $p = Mojo::Promise->new;

    for my $hd (@{$self->handlers}) {
        next if !eq_irc($chan, $from) && $self->handler->{$hd}->generic
            && !$self->chans->{$chan}->{generic};

        my $_p = $self->handler->{$hd}->process_p($chan, $from, $text, $mentioned);

        next if !blessed $_p;

        $_p->then(sub($reply) {
            $self->sendMsg($self->handler->{$hd}->dm ? $from : $chan, $_)
                for @$reply;

            $p->resolve(1);
        });

        return $p;
    }

    return $p->resolve(0);
};

# constructor
sub new($class, %args) {
    my $config = $args{config};

    return $class->SUPER::new(
        %args,
        tls => $config->{tls} eq 'on' ? {} : undef,
        map { $_ => $config->{$_} } grep { $config->{$_} } qw(nick user pass server)
    );
}

# public methods
sub sendMsg($self, $to, $msg) {
    $self->write(PRIVMSG => $to => ":$msg", sub($irc, $err) {
        return warn $err if $err;

        # log own messages
        my $nick = $self->nick;
        $self->$log($self->parser->parse(":$nick PRIVMSG $to :$msg"));
    });
}

sub irc_nick($self, $message) {
    $self->SUPER::irc_nick($message);

    Mojo::IOLoop->timer(10 => sub { $self->write(NICK => $self->config->{nick}) })
        if !eq_irc($self->nick, $self->config->{nick});
}

sub irc_notice($self, $message) {
    $self->SUPER::irc_notice($message);

    my ($from, $to, $text) = $self->utils->getFromToText($message);

    $self->write(NICK => $self->config->{nick})
        if eq_irc($from, 'NickServ') && $text =~ /has\s+been\s+ghosted/i;
}

sub err_nicknameinuse($self, $message) {
    $self->write(PRIVMSG => 'NickServ' => ':GHOST ' . $self->config->{nick});
}

sub start($self) {
    # SQLite table migration
    $self->sqlite->auto_migrate(1)->migrations->from_data(__PACKAGE__, 'irclog.sql');

    for my $chan (keys %{$self->chans}) {
        next if !$self->chans->{$chan}->{log};

        my $schan = $stripChanPrefix->($chan);

        $self->sqlite->db->insert('channel_list', { channel => $schan });

        $self->sqlite->db->update('channel', { public => $self->chans->{$chan}->{public} ? 1 : 0 },
            { channel => $schan });
    }

    # logging
    $self->on(message => sub($irc, $msg) { $self->$log($msg) });

    # interactive
    $self->on(irc_privmsg => sub($irc, $msg) {
        my $nick = $irc->nick;
        my ($from, $to, $text) = $self->utils->getFromToText($msg);

        # don't reply to messages from ZNC et al.
        return if !is_valid_nick_name($from);

        # handle DMs
        return $self->$process_p($from, $from, $text, 1) if eq_irc($nick, $to);

        return if !$self->chans->{$to}->{interactive};

        # in case the nick has changed.
        my $cfgNick = $self->config->{nick};
        my $nickRE  = eq_irc($nick, $cfgNick) ? qr/$nick/i : qr/$nick|$cfgNick/i;
        my $mention = $text =~ /(?:^|[^a-z\d_\-\[\]\\^{}|`])$nickRE(?:[^a-z\d_\-\[\]\\^{}|`]|$)/i;

        $self->$process_p($to, $from, $text, $mention)->then(sub($handled) {
            # register the user to the mutemap (will be used by generic handlers)
            $self->utils->muted(\$self->mutemap->{user}, $from) if $mention && $handled;
        });
    });

    # error handling
    $self->on(error => sub($irc, $msg) {
        warn $msg;
    });

    # try to reconnect if the connection has been closed
    $self->on(close => sub($irc) {
        warn "disconnected, trying to reconnect in 10 seconds\n";
        Mojo::IOLoop->timer(10 => sub { $self->$connect });
    });

    # connect to the configured channels
    $self->$connect;
}

1;

__DATA__

@@ irclog.sql

-- 1 up

CREATE TABLE channel (
     channel_id INTEGER PRIMARY KEY AUTOINCREMENT,
     channel TEXT UNIQUE NOT NULL,
     public INTEGER NOT NULL DEFAULT 0,
     topic TEXT
);

CREATE TABLE command (
     command_id INTEGER PRIMARY KEY AUTOINCREMENT,
     command TEXT UNIQUE NOT NULL
);

CREATE TABLE nick (
     nick_id INTEGER PRIMARY KEY AUTOINCREMENT,
     nick TEXT UNIQUE NOT NULL COLLATE NOCASE
);

CREATE TABLE message (
     message_id INTEGER PRIMARY KEY AUTOINCREMENT,
     ts DATETIME NOT NULL,
     command_id INTEGER NOT NULL REFERENCES command(command_id),
     channel_id INTEGER NOT NULL REFERENCES channel(channel_id),
     nick_id INTEGER NOT NULL REFERENCES nick(nick_id),
     message TEXT
);

CREATE INDEX idx_message_1 ON message (ts, channel_id, nick_id);

CREATE VIEW log (
    message_id, ts, command, channel, public, nick, message
)
AS SELECT message_id, ts, command, channel, public, nick, message
FROM message
JOIN command USING(command_id)
JOIN channel USING(channel_id)
JOIN nick USING(nick_id);

CREATE TRIGGER log_insert
INSTEAD OF INSERT ON log
BEGIN
    INSERT INTO nick(nick)
    SELECT NEW.nick
    WHERE NOT EXISTS(SELECT nick_id FROM nick WHERE nick = NEW.nick);

    INSERT INTO message(ts, command_id, channel_id, nick_id, message)
        SELECT NEW.ts, command_id, channel_id, nick_id, NEW.message
        FROM nick, command, channel
        WHERE nick.nick = NEW.nick
        AND command.command = NEW.command
        AND channel.channel = NEW.channel;
END;

CREATE VIRTUAL TABLE fts_message USING fts5 (
     message_id UNINDEXED,
     message
);

CREATE TRIGGER fts_message_ai AFTER INSERT ON message
WHEN NEW.command_id = 1
BEGIN
    INSERT INTO fts_message(message_id, message)
    VALUES(NEW.message_id, NEW.message);
END;

CREATE VIEW channel_list(channel) as SELECT channel FROM channel;
CREATE TRIGGER channel_insert
INSTEAD OF INSERT ON channel_list
BEGIN
    INSERT INTO channel(channel)
    SELECT NEW.channel
    WHERE NOT EXISTS(
        SELECT channel_id FROM channel WHERE channel = NEW.channel
    );
END;

INSERT INTO command(command) VALUES ('PRIVMSG'), ('JOIN'), ('PART');

-- 2 up

INSERT INTO command(command) VALUES ('QUIT'), ('NICK');

__END__

=head1 COPYRIGHT

Copyright 2022 OmniOS Community Edition (OmniOSce) Association.

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
