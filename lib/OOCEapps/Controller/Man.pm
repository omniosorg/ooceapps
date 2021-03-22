package OOCEapps::Controller::Man;
use Mojo::Base 'OOCEapps::Controller::base';

use Mojo::DOM;
use Mojo::File;

sub process {
    my $c = shift;

    my $man  = lc ($c->stash('man') || '');
    my $sect = lc ($c->stash('sect') || '');

    ($man, my $sec) = split /\./, $man, 2;
    $sect =~ s/^man// if $sect;
    $sect ||= $sec;

    return $c->reply->not_found if !exists $c->model->index->{$man}
        || ($sec && $sect && $sec ne $sect)
        || ($sect && !exists $c->model->index->{$man}->{$sect});

    my @sect = sort keys %{$c->model->index->{$man}};

    if (!$sect && @sect > 1) {
        my $html = Mojo::DOM->new;

        my $alt = [];
        for my $s (@sect) {
            my $f = Mojo::File->new($c->model->config->{mandir}, $c->model->index->{$man}->{$s});

            if (-r $f) {
                $html->parse($f->slurp);
                push @$alt, {
                    sect => $s,
                    vol  => $html->at('table.head > tr > td.head-vol')->text,
                    sum  => $html->at('div.manual-text > section.Sh')->text,
                };

                next;
            }

            push @$alt, {
                sect => $s,
                vol  => '',
                sum  => '',
            };
        }

        $c->stash(alternates => $alt);
        return $c->render(template => 'man/multiSection', format => 'html');
    }

    $sect ||= $sect[0];
    $c->reply->static($c->model->index->{$man}->{$sect});
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

2018-04-08 had Initial Version

=cut

