package OOCEapps::Module::base;
use Mojo::Base 'Mojolicious::Controller';

use File::Path qw(make_path);
use OOCEapps::Mattermost;

# attributes
has schema  => sub { {} };
has config  => sub { {} };
has module  => sub { return ref shift };
has name    => sub { return lc ((split /::/, shift->module)[-1]) };
has datadir => sub { };

# public methods
sub register {
    my $self = shift;
    my $app  = shift;

    # set module specific datadir and create it if it does not exist
    $self->datadir($app->datadir . '/' . $self->name);
    -d $self->datadir || make_path($self->datadir);

    # this registers a default route for the module using the module's name
    # override it in subclass if necessary
    $app->routes->post('/' . $self->name)
        ->to(namespace => $self->module, action => 'process');
}

sub process {
    shift->render(json => OOCEapps::Mattermost->error('process not implemented...'));
}

sub cleanup {
    # override in subclass if something needs to be cleaned up on exit (e.g. forks)
}

1;

