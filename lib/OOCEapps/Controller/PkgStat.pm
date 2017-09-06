package OOCEapps::Controller::PkgStat;
use Mojo::Base 'OOCEapps::Controller::base';

use Mojo::JSON qw(decode_json);

# attributes
has pkgDB => sub { shift->config->{pkgDB} }; 

#private methods
my $formatNumber = sub { scalar reverse join ',', unpack '(A3)*', reverse shift };

my $getPkgStat = sub {
    my $self = shift;
    my $days = shift // '0';

    return OOCEapps::Mattermost->error("input for days '$days' is not numeric.")
        if $days !~ /^\d+$/;

    my @data;
    push @data, "### IPS repo stats for the last $days days:" if $days;
    push @data, [ 'Country', 'Unique IP', 'Access Count' ];
    push @data, [ qw(:--- ---: ---:) ];

    my $ips = 0;
    my $acc = 0;

    # load db
    open my $fh, '<', $self->pkgDB
        or return OOCEapps::Mattermost->error('DB cannot be opened. Try again later.');

    my $DB = decode_json do { local $/; <$fh> };
    close $fh;

    my %db;
    for my $day (keys %$DB) {
        next if $days && $day > $days;

        for my $country (keys %{$DB->{$day}}) {
            $db{$country}->{$_} += $DB->{$day}->{$country}->{$_} // 0 for qw(unique total);
        }
    }

    for my $country (sort { $db{$b}->{unique} <=> $db{$a}->{unique}
        || $db{$b}->{total} <=> $db{$a}->{total} } keys %db) {

        $ips += $db{$country}->{unique};
        $acc += $db{$country}->{total};

        push @data, [ $country, $formatNumber->($db{$country}->{unique}),
            $formatNumber->($db{$country}->{total}) ];
    }

    push @data, [ '**Total**', '**' . $formatNumber->($ips) . '**',
        '**' . $formatNumber->($acc) . '**' ];
    push @data, '---';

    return OOCEapps::Mattermost->table(\@data);
};

sub process {
    my $c = shift;
    my $t = $c->param('text') || '0';

    $c->render(json => $c->$getPkgStat($t));
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

