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

