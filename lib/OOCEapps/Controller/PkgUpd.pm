package OOCEapps::Controller::PkgUpd;
use Mojo::Base 'OOCEapps::Controller::base';

use Mojo::IOLoop::Subprocess;
use Mojo::Promise;
use Sort::Versions;

#private methods
my $getPkgAvailVer = sub {
    my $self    = shift;
    my $pkgList = shift;
    my $repo    = shift || $self->config->{default};

    #we can't handle ftp URLs
    my @pkgs = sort grep { $pkgList->{$_}->{url} !~ /^ftp/ } keys %$pkgList;
    my @chunks;
    push @chunks, [ splice @pkgs, 0, $self->config->{chunksize} ] while @pkgs;

    my @data;
    push @data, "### Available Package Updates for '$repo'";
    push @data, [ qw(Package Version Notes) ];
    push @data, [ qw(:--- :--- :---) ];

    $self->ua->max_redirects(8)->connect_timeout(12)->request_timeout(16);

    Mojo::Promise->map(sub {
        my $chunk = shift;

        Mojo::IOLoop::Subprocess->new->run_p(sub {
            my $pl = {};

            Mojo::Promise->map(sub {
                $self->ua->get_p($pkgList->{$_}->{url})->catch(sub { })
            }, @$chunk
            )->then(sub {
                my @tx = @_;

                for (my $i = 0; $i <= $#$chunk; $i++) {
                    ($tx[$i]->[0] && $tx[$i]->[0]->result->is_success) || do {
                        $pl->{$chunk->[$i]}->{availVer} = [];
                        $pl->{$chunk->[$i]}->{timeout}  = 1;
                        next;
                    };

                    $pl->{$chunk->[$i]}->{availVer} = $self->config->{parser}
                        ->{exists $self->config->{parser}->{$chunk->[$i]} ? $chunk->[$i] : 'DEFAULT'}
                        ->getVersions($chunk->[$i], $tx[$i]->[0]->result);
                }
            })->wait;

            return $pl;
        });
    }, @chunks
    )->then(sub {
        my @pls = @_;

        for my $pl (@pls) {
            for my $pkg (sort keys %{$pl->[0]}) {
                my $url = $pkgList->{$pkg}->{xurl} ? "[$pkg]($pkgList->{$pkg}->{xurl}) ([data]($pkgList->{$pkg}->{url}))"
                        :                            "[$pkg]($pkgList->{$pkg}->{url})";

                @{$pl->[0]->{$pkg}->{availVer}} || do {
                    push @data, [
                        $url,
                        "$pkgList->{$pkg}->{version} -> "
                            . ($pl->[0]->{$pkg}->{timeout} ? 'timeout :face_with_head_bandage:'
                            :                                'cannot parse versions :panic:'),
                        $pkgList->{$pkg}->{notes}
                    ];

                    next;
                };

                my $latest = (sort { versioncmp($a, $b) } @{$pl->[0]->{$pkg}->{availVer}})[-1];

                push @data, [
                    $url,
                    "$pkgList->{$pkg}->{version} -> $latest",
                    $pkgList->{$pkg}->{notes}
                ] if versioncmp($pkgList->{$pkg}->{version}, $latest);
            }
        }

        # add a dummy entry if the table would be empty; so markdown does not break
        push @data, [ ' ', ' ', ' ' ] if @data <= 3;
        $self->render(json => OOCEapps::Mattermost->table(\@data));
    })->wait;
};

sub process {
    my $c = shift;

    my $repo = $c->param('text');

    return if !$c->checkToken;
    # increase inactivity timeout
    $c->inactivity_timeout(28);
    $c->render_later;

    my $pkgList = $c->model->getPkgList($repo);

    keys %$pkgList or do {
        $c->render(json => OOCEapps::Mattermost->error("could not get package list for repo '$repo'"));
        return;
    };

    $c->$getPkgAvailVer($pkgList, $repo);
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

