package OOCEapps::Controller::Man;
use Mojo::Base 'OOCEapps::Controller::base';

use Mojo::DOM;
use Mojo::File;

# see: https://github.com/illumos/ipd/blob/master/ipd/0004/README.md
my %secrenmap = (
    qr/1m$/ => '8',
    qr/4$/  => '5',
    qr/5$/  => '7',
    qr/7/   => '4',
);

sub process {
    my $c = shift;

    my $man  = lc ($c->stash('man') // '');
    my $sect = lc ($c->stash('sect') // '');

    $man  =~ s/\.html$//;
    $sect =~ s/^man//;

    ($man, my $sec) = $man =~ /^(.+?)(?:\.(\d[^.]*))?$/
        if !exists $c->model->index->{$man};

    $sec = lc ($sec // '');
    $sect ||= $sec;

    return $c->reply->not_found
        if !exists $c->model->index->{$man} || ($sec && $sect && $sec ne $sect);

    # handle manual page section renumbering to avoid breaking existing links
    # e.g. in release notes or IRC logs
    # see: https://github.com/illumos/ipd/blob/master/ipd/0004/README.md
    if ($sect && !exists $c->model->index->{$man}->{$sect}) {
        $sect =~ s/^$_/$secrenmap{$_}/ and last for keys %secrenmap;

        return $c->reply->not_found if !exists $c->model->index->{$man}->{$sect};

        # moved permanently
        # $c->res->code(301);
        return $c->redirect_to($c->model->config->{path_prefix}
            . ($sec ? "/$man.$sect" : "/$sect/$man"));
    }

    my @sect = sort keys %{$c->model->index->{$man}};

    if (!$sect && @sect > 1) {
        my $html = Mojo::DOM->new;

        my $alt = [];
        for my $s (@sect) {
            my $f = Mojo::File->new($c->model->config->{mandir}, $c->model->index->{$man}->{$s});

            # skip symlinks from a section we already added
            next if -l $f && grep { $_->{sect} eq $s } @$alt;

            # set the current section in case we end up
            # with just one non-symlinked section
            $sect = $s;

            if (-r $f) {
                $html->parse($f->slurp);
                my $sum;
                if (my $res = $html->at('div.manual-text > section.Sh > div.Nd')) {
                    $sum = $html->at('div.manual-text > section.Sh')->find('code.Nm')
                        ->map('text')->join(', ') . ' - ' . $res->text;
                }
                else {
                    $sum = $html->at('div.manual-text > section.Sh')->text;
                }
                push @$alt, {
                    sect => $s,
                    vol  => $html->at('table.head > tr > td.head-vol')->text,
                    sum  => $sum,
                };

                next;
            }

            push @$alt, {
                sect => $s,
                vol  => '',
                sum  => '',
            };
        }

        if (@$alt > 1) {
            $c->stash(alternates => $alt);
            return $c->render(template => 'man/multiSection', format => 'html');
        }
    }

    $sect ||= $sect[0];
    $c->reply->static($c->model->index->{$man}->{$sect});
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

2018-04-08 had Initial Version

=cut

