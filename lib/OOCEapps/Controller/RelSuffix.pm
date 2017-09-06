package OOCEapps::Controller::RelSuffix;
use Mojo::Base 'OOCEapps::Controller::base';

use Time::Piece;
use Time::Seconds;

#private methods
my $getW_C = sub {
    my $date = shift;

    return $date - Time::Seconds::ONE_DAY * (($date->wday + 5) % 7);
};

my $getRelease = sub {
    my $rel   = shift;
    my $index = shift;

    return 'n/a' if $index < 0;

    my $ord_a = ord ('a');
    my $cycle = ord ('z') - $ord_a + 1;
    my $major = int ($index / $cycle);
    my $minor = int ($index % $cycle);

    return "$rel**" . ($major ? chr ($major - 1 + $ord_a) : '') . chr ($minor + $ord_a) . '**';
};

my $getRelSuffixes = sub {
    my $self = shift;
    my $t    = shift // '0';

    my $date;
    if ($t =~ /^\d{4}-\d{1,2}-\d{1,2}$/) {
        $date = Time::Piece->strptime($t, '%Y-%m-%d');
    }
    else {
        return OOCEapps::Mattermost->error("input for weeks ahead '$t' is not numeric.")
            if $t !~ /^-?\d+$/;

        $date = gmtime () + $t * Time::Seconds::ONE_WEEK;
    }
    $date = $getW_C->($date);

    my @releases = sort keys %{$self->config};

    my @data;
    push @data, [ 'w/c', @releases ];
    push @data, [ ':---', map { ':---:' } @releases ];
    push @data, [ $date->ymd, map { $getRelease->($_, ($date
        - $getW_C->(Time::Piece->strptime($self->config->{$_}, '%Y-%m-%d')))->weeks) } @releases ];
    push @data, '---';

    return OOCEapps::Mattermost->table(\@data);
};

sub process {
    my $c = shift;
    my $t = $c->param('text') || '0';

    $c->render(json => $c->$getRelSuffixes($t));
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

