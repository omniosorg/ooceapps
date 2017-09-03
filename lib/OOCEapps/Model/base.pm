package OOCEapps::Model::base;
use Mojo::Base 'Mojolicious::Controller';

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

