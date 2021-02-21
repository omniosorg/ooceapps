package OOCEapps::Controller::Issue;
use Mojo::Base 'OOCEapps::Controller::base';

use OOCEapps::Mattermost;

sub process {
    my $c = shift;
    my $p = $c->param('text');

    $c->checkToken;

    #default to illumos if just a number is provided
    $p = "illumos $p" if $p =~ /^\d+$/;

    my $issue = $c->model->issue->process(qw(ooceapps ooceapps), $p);
    $c->render(json => OOCEapps::Mattermost->text(@$issue ? join ("\n", @$issue)
        : "no issue found using search string '$p'"));
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

2018-05-04 had Initial Version

=cut

