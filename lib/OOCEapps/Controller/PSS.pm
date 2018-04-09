package OOCEapps::Controller::PSS;
use Mojo::Base 'OOCEapps::Controller::base';

sub process {
    my $c = shift;
    my @p = map { $c->param($_) } qw(user_name channel_name text);

    $c->checkToken;
    $c->render(json => $c->model->play(@p));
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

2018-04-08 had Initial Version

=cut

