package OOCEapps::Model::PSS;
use Mojo::Base 'OOCEapps::Model::base';

use Mojo::File;
use Mojo::JSON qw(encode_json decode_json);
use OOCEapps::Mattermost;

# attributes
has gamesdb => sub { shift->datadir . '/games.json' };
has schema  => sub {
    my $sv = shift->utils;

    return {
        timeout => {
            description => 'time in seconds a game times out',
            example     => 60,
            default     => 60,
            validator   => $sv->regexp(qr/^\d+$/, 'expected a numeric input'),
        },
        token => {
            optional    => 1,
            description => 'Mattermost token',
            example     => 'abcd1234',
            validator   => $sv->regexp(qr/^\w+$/, 'expected an alphanumeric string'),
        },
    }
};

# private methods
my $loadGames = sub {
    return decode_json(Mojo::File->new(shift->gamesdb)->slurp);
};

my $saveGames = sub {
    Mojo::File->new(shift->gamesdb)->spurt(encode_json shift);
};

my $getGame = sub {
    my $self  = shift;
    my $chan  = shift;

    my $games = $self->$loadGames;

    return undef if !exists $games->{$chan};

    return $games->{$chan};
};

my $addGame = sub {
    my $self   = shift;
    my $chan   = shift;
    my $user   = shift;
    my $choice = shift;

    my $games = $self->$loadGames;

    my $id = int (rand (10000) + 1);

    $games->{$chan} = {
        user   => $user,
        choice => $choice,
        id     => $id,
    };

    $self->$saveGames($games);

    return $id;
};

my $resetGame = sub {
    my $self = shift;
    my $chan = shift;
    my $id   = shift;

    my $games = $self->$loadGames;

    exists $games->{$chan} && (!$id || $id eq $games->{$chan}->{id}) && do {
        delete $games->{$chan};
        $self->$saveGames($games);
    };
};

my $choicecmp = sub {
    my $a = shift;
    my $b = shift;

    return 0 if $a eq $b;

    for ($a) {
        /^paper$/    && return $b eq 'stone'    ? 1 : -1;
        /^stone$/    && return $b eq 'scissors' ? 1 : -1;
        /^scissors$/ && return $b eq 'paper'    ? 1 : -1;
    }

    # not reached
    return 0;
};

my $getTrophy = sub {
    my $win   = shift;
    my $other = shift;

    my $res = $other ? -$win : $win;

    return $res > 0 ? ':trophy:' : ':unamused:';
};

sub play {
    my $self   = shift;
    my $user   = shift;
    my $chan   = shift;
    my $choice = lc shift;

    return OOCEapps::Mattermost->error("choice must be 'paper', 'stone' or 'scissors'.",
        { response_type => 'ephemeral' }) if !grep { /^$choice$/ } qw(paper stone scissors);

    my $game = $self->$getGame($chan);
    # check if there is an active game in the channel
    $game || do {
        my $id = $self->$addGame($chan, $user, $choice);
        # create a timer to reset the game after timeout seconds
        Mojo::IOLoop->timer($self->config->{timeout} => sub { $self->$resetGame($chan, $id) });
        return OOCEapps::Mattermost->text("$user started a PSS game. The game is timing out in "
            . $self->config->{timeout} . ' seconds.');
    };

    $self->$resetGame($chan);

    # check if the same user is playing
    return OOCEapps::Mattermost->text("Playing with yourself $user? Go and get some friends :stuck_out_tongue_closed_eyes:")
        if $game->{user} eq $user;

    # check who won
    my $win = $choicecmp->($game->{choice}, $choice);

    return OOCEapps::Mattermost->text("both, $game->{user} and $user chose '$choice'.")
        if !$win;

    return OOCEapps::Mattermost->text("$game->{user} chose '$game->{choice}': " . $getTrophy->($win)
        . "\n$user chose '$choice': " . $getTrophy->($win, 1));
}

sub register {
    my $self = shift;
    my $app  = shift;

    $self->SUPER::register($app);

    # always start from scratch on restart
    $self->$saveGames({});
}

1;

__END__

=head1 COPYRIGHT

Copyright 2018 OmniOS Community Edition (OmniOSce) Association.

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

2018-04-08 had Initial Version

=cut

