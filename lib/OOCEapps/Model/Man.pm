package OOCEapps::Model::Man;
use Mojo::Base 'OOCEapps::Model::base';

use Mojo::File;

# attributes
has schema  => sub {
    my $sv = shift->utils;

    return {
        mandir      => {
            description => 'path to man pages',
            example     => '/website/man',
            validator   => $sv->dir('cannot access directory'),
        },
        path_prefix => {
            description => 'URL path prefix',
            default     => '/man',
            example     => '/man',
            validator   => $sv->regexp(qr!^(?:/.+|)$!, 'expected an empty string or a string with a leading slash'),
        },
    }
};

has index   => sub {
    my $self = shift;

    my $mandir = Mojo::File->new($self->config->{mandir});

    my %index;
    for my $file ($mandir->list_tree({ max_depth => 2 })->each) {
        my ($man, $sect) = $file =~ m!/([^/]+)\.(\d[^.]*)\.html$!
            or next;

        $index{lc $man}->{lc $sect} = $file->to_rel($mandir);
    }

    return \%index;
};

# public methods
sub register {
    my $self = shift;

    # serve static pages from mandir
    unshift @{$self->app->static->paths}, $self->config->{mandir};

    # build index on startup
    $self->index;

    $self->app->routes->get('/' . $self->name . '/#man')
        ->to(controller => $self->controller, action => 'process');
    $self->app->routes->get('/' . $self->name . '/:sect/#man')
        ->to(controller => $self->controller, action => 'process');
}

1;

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

2017-09-06 had Initial Version

=cut

