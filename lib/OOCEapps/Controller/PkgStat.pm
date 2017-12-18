package OOCEapps::Controller::PkgStat;
use Mojo::Base 'OOCEapps::Controller::base';

use Mojo::JSON qw(decode_json);

# attributes
has pkgDB => sub { shift->config->{pkgDB} }; 

#private methods
my $formatNumber = sub { scalar reverse join ',', unpack '(A3)*', reverse shift };

my $getPkgStat = sub {
    my $self = shift;
    my $args = shift;

    # set defaults
    my $days = 0;
    my $rel  = 'total';
    for (split /\s+/, $args) {
        /^\d+$/ && do {
            $days = $_;
            next;
        };
        $rel = $_;
    }

    my @data;
    push @data, "### $rel IPS stats" . ($days ? " for the last $days day(s):" : ':');
    push @data, [ 'Country', 'Unique IPS images', 'Unique IP', 'Access Count' ];
    push @data, [ qw(:--- ---: ---: ---:) ];

    my $uuids = 0;
    my $ips   = 0;
    my $acc   = 0;

    # load db
    open my $fh, '<', $self->pkgDB
        or return OOCEapps::Mattermost->error('DB cannot be opened. Try again later.');

    my $DB = decode_json do { local $/; <$fh> };
    close $fh;

    # get timestamp and remove it from data structure
    my $updTS = $DB->{update_ts};
    delete $DB->{update_ts};

    exists $DB->{$rel}
        or return OOCEapps::Mattermost->error("No data for release '$rel'.");

    my %db;
    for my $day (keys %{$DB->{$rel}}) {
        next if $days && $day > $days;

        for my $country (keys %{$DB->{$rel}->{$day}}) {
            $db{$country}->{$_} += $DB->{$rel}->{$day}->{$country}->{$_} // 0 for qw(uuids unique total);
        }
    }

    for my $country (sort { $db{$b}->{uuids} <=> $db{$a}->{uuids}
        || $db{$b}->{unique} <=> $db{$a}->{unique}
        || $db{$b}->{total} <=> $db{$a}->{total} } keys %db) {

        $uuids += $db{$country}->{uuids};
        $ips   += $db{$country}->{unique};
        $acc   += $db{$country}->{total};

        push @data, [ $country, $formatNumber->($db{$country}->{uuids}),
            $formatNumber->($db{$country}->{unique}), $formatNumber->($db{$country}->{total}) ];
    }

    push @data, [ '**Total**',  '**' . $formatNumber->($uuids) . '**',
        '**' . $formatNumber->($ips) . '**', '**' . $formatNumber->($acc) . '**' ];
    push @data, "Last statistics update at: $updTS";

    return OOCEapps::Mattermost->table(\@data);
};

sub process {
    my $c = shift;
    my $p = $c->param('text');

    $c->checkToken;
    $c->render(json => $c->$getPkgStat($p));
}

1;

__END__

=head1 COPYRIGHT

Copyright 2017 OmniOS Community Edition (OmniOSce) Association.

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

