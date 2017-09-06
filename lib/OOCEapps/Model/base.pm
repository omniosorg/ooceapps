package OOCEapps::Model::base;
use Mojo::Base -base;

use File::Path qw(make_path);
use OOCEapps::Mattermost;

# attributes
has app     => sub { {} };
has module  => sub { ref shift };
has name    => sub { lc ((split /::/, shift->module)[-1]) };
has config  => sub { my $self = shift; $self->app->config->{MODULES}->{$self->name} };
has datadir => sub { my $self = shift; $self->app->datadir . '/' . $self->name };
has schema  => sub { {} };

# public methods
sub register {
    my $self = shift;
    my $app  = shift;

    $self->app($app);
    # create module datadir if it does not exist
    -d $self->datadir || make_path($self->datadir);

    # this registers a default route for the module using the module's name
    # override it in subclass if necessary
    # my $controller = $self->module =~ s/Model/Controller/r;
    my $controller = $self->module;
    $controller =~ s/Model/Controller/;
    $app->routes->post('/' . $self->name)
        ->to(namespace => $controller, action => 'process');
}

sub process {
    shift->render(json => OOCEapps::Mattermost->error('process not implemented...'));
}

sub cleanup {
    # override in subclass if something needs to be cleaned up on exit (e.g. forks)
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

