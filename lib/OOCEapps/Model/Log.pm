package OOCEapps::Model::Log;
use Mojo::Base 'OOCEapps::Model::base';

use Mojo::File;

# attributes
has schema  => sub {
    my $sv = shift->utils;

    return {
        logdir   => {
            description => 'path to log files',
            example     => '/var/opt/ooce/ooceapps/fenix',
            validator   => $sv->dir('cannot access directory'),
        },
        channels => {
            array       => 1,
            description => 'channels to expose to the log page',
            example     => '#omnios',
            validator   => sub {
                my $chan = shift;
                my $dir  = shift->{logdir};

                return $sv->dir('cannot access directory')->(Mojo::File->new($dir, $chan));
            },
        },
    }
};

has chanmap   => sub { return { map { $_ => undef } @{shift->config->{channels}} } };
has filtermap => sub { return { map { $_ => undef } qw(JOIN PART PRIVMSG) } };
has index     => sub {
    my $self = shift;

    return {
        map {
            my $chan = $_;
            my $d    = Mojo::File->new($self->config->{logdir}, $chan);
            my $logs = $d->list->grep(qr/\d{4}(?:-\d\d){2}\.json$/)->sort;
            my $tf   = Mojo::File->new($self->config->{logdir}, $chan, '__currtopic');

            $chan =~ s/^#//;
            $chan => {
                begin => $logs->first->basename('.json'),
                topic => -r $tf ? $tf->slurp : 'n/a',
            }
        } @{$self->config->{channels}}
    };
};

# public methods
sub register {
    my $self = shift;

    # build index on startup
    $self->index;

    $self->app->routes->get('/' . $self->name . '/api/channel')
        ->to(controller => $self->controller, action => 'channel');
    $self->app->routes->get('/' . $self->name . '/api/:chan/:date')
        ->to(controller => $self->controller, action => 'getlog');
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

