package OOCEapps::Controller::PkgUpd;
use Mojo::Base 'OOCEapps::Controller::base';

use Sort::Versions;

#private methods
my $getPkgAvailVer = sub {
    my $self    = shift;
    my $pkgList = shift;

    my @pkgs = sort keys %$pkgList;

    my @data;
    push @data, "### Available Package Updates";
    push @data, [ qw(Package Version Notes) ];
    push @data, [ qw(:--- :--- :---) ];
    $self->delay(
        sub {
            my $delay = shift;
            $self->ua->max_redirects(5) #->connect_timeout(10)->request_timeout(10)
                ->get($pkgList->{$_}->{url} => $delay->begin) for @pkgs;
        },
        sub {
            my ($delay, @tx) = @_;

            for (my $i = 0; $i <= $#pkgs; $i++) {
                $tx[$i]->success || do {
                    $pkgList->{$pkgs[$i]}->{availVer} = [];
                    $pkgList->{$pkgs[$i]}->{timeout}  = 1;
                    next;
                };

                $pkgList->{$pkgs[$i]}->{availVer} = $self->config->{parser}
                    ->{exists $self->config->{parser}->{$pkgs[$i]} ? $pkgs[$i] : 'DEFAULT'}
                    ->getVersions($pkgs[$i], $tx[$i]->result);
            }
            for my $pkg (sort keys %$pkgList) {
                @{$pkgList->{$pkg}->{availVer}} || do {
                    push @data, [ "[$pkg]($pkgList->{$pkg}->{url})",
                        ($pkgList->{$pkg}->{timeout} ? 'timeout :face_with_head_bandage:'
                            : 'cannot parse versions :panic:'),
                        $pkgList->{$pkg}->{notes} ];
                    next;
                };
                my $latest = (sort { versioncmp($a, $b) } @{$pkgList->{$pkg}->{availVer}})[-1];
                push @data, [ "[$pkg]($pkgList->{$pkg}->{url})",
                    "$pkgList->{$pkg}->{version} -> $latest",
                    $pkgList->{$pkg}->{notes} ]
                    if versioncmp($pkgList->{$pkg}->{version}, $latest); 
            }

            $self->render(json => OOCEapps::Mattermost->table(\@data));
        }
    );
};

sub process {
    my $c = shift;

    $c->checkToken;
    # increase inactivity timeout
    $c->inactivity_timeout(30);
    $c->render_later;

    my $pkgList = $c->model->getPkgList;

    keys %$pkgList or do {
        $c->render(json => OOCEapps::Mattermost->error('could not get package list'));
        return;
    };

    $c->$getPkgAvailVer($pkgList);
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

