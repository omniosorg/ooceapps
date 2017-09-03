package OOCEapps::Controller::base;
use Mojo::Base 'Mojolicious::Controller';

use OOCEapps::Mattermost;

# attributes
has module  => sub { ref shift };
has name    => sub { lc ((split /::/, shift->module)[-1]) };
has config  => sub { my $self = shift; $self->app->config->{MODULES}->{$self->name} };

sub process {
    shift->render(json => OOCEapps::Mattermost->error('process not implemented...'));
}

1;

