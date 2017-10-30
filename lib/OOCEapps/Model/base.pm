package OOCEapps::Model::base;
use Mojo::Base -base;

use File::Path qw(make_path);
use OOCEapps::Mattermost;

# attributes
has app     => sub { {} };
has module  => sub { ref shift };
has name    => sub { lc ((split /::/, shift->module)[-1]) };
has config  => sub { my $self = shift; $self->app->config->{MODULES}->{$self->name} };
has log     => sub { shift->app->log };
has datadir => sub { my $self = shift;
    my $dir = $self->app->datadir . '/' . $self->name;
    # create module datadir if it does not exist
    -d $dir || make_path($dir);
    chmod 0700, $dir;
    return $dir;
 };

has controller => sub {
    my $controller = shift->module;
    $controller =~ s/Model/Controller/;
    return $controller;
};

has schema  => sub { {} };

# public methods
sub register {
    my $self = shift;

    # this registers a default route for the module using the module's name
    # override it in subclass if necessary
    # my $controller = $self->module =~ s/Model/Controller/r;
    $self->app->routes->post('/' . $self->name)
        ->to(namespace => $self->controller, action => 'process');
}

1;

__END__

=head1 COPYRIGHT

Copyright 2017 OmniOS Community Edition (OmniOSce) Association.

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

S<Dominik Hassler E<lt>hadfl@omniosce.orgE<gt>>

=head1 HISTORY

2017-09-06 had Initial Version

=cut
