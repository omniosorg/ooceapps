package Fenix;
use Mojo::Base 'Mojolicious', -signatures;

use Data::Processor;
use Mojo::JSON qw(decode_json);
use Mojo::File;
use Mojo::Home;

use Fenix::Model::IRC;
use OOCEapps::Utils;

# constants
my $CONFFILE = $ENV{FENIX_CONF} || Mojo::Home->new->rel_file('../etc/fenix.conf')->to_string; # CONFFILE
my $DATADIR  = Mojo::Home->new->rel_file('../var')->to_string; # DATADIR

# attributes
has datadir => $DATADIR . '/' . lc __PACKAGE__;
has utils   => sub { OOCEapps::Utils->new };

has schema  => sub {
    my $sv = shift->utils;

    return {
        nick    => {
            description => 'nick',
            default     => 'fenix',
            example     => 'fenix',
            validator   => $sv->regexp(qr/^\w+$/, 'expected a string'),
        },
        user    => {
            optional    => 1,
            description => 'user',
            example     => 'fenix',
            validator   => $sv->regexp(qr/^\w+$/, 'expected a string'),
        },
        pass    => {
            optional    => 1,
            description => 'nick',
            example     => 'fenix',
            validator   => $sv->regexp(qr/^.+$/, 'expected a string'),
        },
        server  => {
            description => 'irc server:port',
            example     => 'irc.freenode.net',
            validator   => $sv->regexp(qr/^[\w.]+(?::\d+)$/, 'expected host[:port]'),
        },
        tls     => {
            description => 'use tls',
            example     => 'on',
            default     => 'on',
            validator   => $sv->elemOf(qw(on off)),
        },
        CHANS   => {
            array       => 1,
            optional    => 1,
            members     => {
                name        => {
                    example     => '#omnios',
                    description => 'channel name',
                    validator   => $sv->regexp(qr/^#[\w-]+$/, 'expected a pound sign prefixed string'),
                },
                log         => {
                    optional    => 1,
                    description => 'channel logging',
                    default     => 'on',
                    validator   => $sv->elemOf(qw(on off)),
                },
                interactive => {
                    optional    => 1,
                    description => 'interactive bot',
                    default     => 'off',
                    validator   => $sv->elemOf(qw(on off)),
                },
            },
        },
    },
};

has config => sub {
    my $app = shift;
    # load config
    my $cfg = decode_json do { Mojo::File->new($CONFFILE)->slurp };

    my $dp = Data::Processor->new($app->schema);
    my $ec = $dp->validate($cfg);
    $ec->count and die join ("\n", map { $_->stringify } @{$ec->{errors}}) . "\n";
    return $cfg;
};

has irc => sub($self) {
    Fenix::Model::IRC->new(
        config  => $self->config,
        datadir => $self->datadir
    )
};

# public methods
sub startup($app) {
    $app->routes->post('/fenix')->to(controller => 'Hooks', action => 'fenix');
    $app->routes->any('/')->to(controller => 'Hooks', action => 'default');

    $app->irc->start;
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
