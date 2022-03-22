package OOCEapps::Controller::Cowsay;
use Mojo::Base 'OOCEapps::Controller::base';

#private methods
my $getCow = sub {
    my $c = shift;

    my ($cow, $text) = shift =~ /^(?:-(\S+)\s+)?(.+)/s;

    my %opts;
    if ($cow && $cow eq 'dragon') {
        $opts{username} = 'Fenix';
    }
    else {
        # default to cow
        $cow = 'cow';
        $opts{username} = 'Mrs Cowley';
    }

    $c->model->$cow->say($text);

    return OOCEapps::Mattermost->code($c->model->$cow->as_string, \%opts);
};

sub process {
    my $c = shift;
    my $t = $c->param('text');

    $c->checkToken && $c->render(json => $c->$getCow($t));
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

