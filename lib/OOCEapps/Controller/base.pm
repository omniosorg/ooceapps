package OOCEapps::Controller::base;
use Mojo::Base 'Mojolicious::Controller';

# attributes
has ua      => sub { shift->app->ua->new };
has module  => sub { ref shift };
has name    => sub { lc ((split /::/, shift->module)[-1]) };
has model   => sub { my $self = shift; $self->app->model->{$self->name} };
has config  => sub { shift->model->config };
has log     => sub { shift->model->log };
has data    => sub { shift->req->json };
has datadir => sub { shift->model->datadir };

# methods
sub process {
    shift->render(text => 'Process not implemented.', status => 404);
}

sub checkToken {
    my $c = shift;

    $c->config->{token} && $c->config->{token} ne $c->param('token')
        && $c->render(text => 'Unauthorised', status => 401);
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

S<Dominik Hassler E<lt>hadfl@omniosce.orgE<gt>>

=head1 HISTORY

2017-09-06 had Initial Version

=cut

