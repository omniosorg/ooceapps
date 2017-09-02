package OOCEapps::Module::PKGstat;
use Mojo::Base 'OOCEapps::Module::base';

use POSIX qw(SIGTERM);
use Time::Piece;
use Geo::IP::PurePerl;
use List::Util qw(max);
use Mojo::JSON qw(decode_json encode_json);
use Mojo::UserAgent;
use IO::Uncompress::Gunzip qw(gunzip $GunzipError);
use FindBin;

# private properties
my $geoipDB;
my $pkgDB;
my $pid = 0;

# attributes
has schema  => sub { {
    members => {
        logdir    => {
            description => 'path to log files',
            example     => '/var/log/nginx',
            validator   => sub { my $d = shift; -d $d ? undef : "cannot access directory '$d'" },
        },
        geoip_url => {
            description => 'url to geoip database',
            example     => 'http://geolite.maxmind.com/download/geoip/database/GeoLiteCountry/GeoIP.dat.gz',
            validator   => sub { my $url = shift; $url =~ /^.*$/ ? undef : 'expected a string' },
        },
    },
} };

#private methods
my $formatNumber = sub { scalar reverse join ',', unpack '(A3)*', reverse shift };

my $parseFiles = sub {
    my $self  = shift;
    my $epoch = gmtime->epoch;
    my $data  = {};

    for my $logfile (glob $self->config->{logdir} . '/access*') {
        open my $fh, '<', $logfile or die "ERROR: opening file '$logfile': $!\n";

        while (my $line = <$fh>) {
            my ($ip, $ts) = $line =~ /^((?:\d{1,3}\.){3}\d{1,3})[^\[]+\[([^\]]+)\].*sunos i86pc/ or next;

            # get how many days the entry is past
            my $days = int(($epoch - Time::Piece->strptime($ts, '%d/%b/%Y:%H:%M:%S %z')->epoch) / (24 * 3600)) + 1;

            $data->{$days}->{$ip}++;
        }

        close $fh;
    }

	my $gip = Geo::IP::PurePerl->new($geoipDB, GEOIP_MEMORY_CACHE);
	my $db = {};
    my %ipTbl;

	for my $day (sort { $a <=> $b } keys %$data) {
    	for my $ip (keys %{$data->{$day}}) {
        	my $country = $gip->country_name_by_addr($ip);

			$db->{$day}->{$country}->{unique}++ if !exists $ipTbl{$ip};
			$db->{$day}->{$country}->{total} += $data->{$day}->{$ip};

            $ipTbl{$ip} = undef;
        }
    }

    # save db
    open my $fh, '>', $pkgDB . '.new' or die "ERROR: opening '" . $pkgDB . "' for writing: $!\n";
    print $fh encode_json $db;
    close $fh;

    rename $pkgDB . '.new', $pkgDB;
};

my $getPkgStat = sub {
    my $app  = shift;
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
    open my $fh, '<', $pkgDB
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


my $refreshDB;
$refreshDB = sub {
    my $self = shift;

    my $proc = Mojo::IOLoop->subprocess(
        sub {
            my $subprocess = shift;
            $self->$parseFiles;
            return undef;
        },
        sub {
            my ($subprocess, $err, $result) = @_;
            $pid = 0;
        }
    );

    $pid = $proc->pid;
    # set next refresh in 1h + a maximum random 5 minutes
    Mojo::IOLoop->timer(3600 + int(rand(300)) => sub { $self->$refreshDB });
};

my $updateGeoIP;
$updateGeoIP = sub {
    my $self = shift;

    my $ua = Mojo::UserAgent->new;
    my $res = $ua->get($self->config->{geoip_url})->result;
    die "ERROR: downloading GeoIP database from '$self->config->{geoip_url}'\n"
        if !$res->is_success;

    $res->content->asset->move_to($geoipDB . '.gz');
    gunzip $geoipDB . '.gz' => $geoipDB
        or die "ERROR: gunzip GeoIP failed: $GunzipError\n";

    unlink $geoipDB . '.gz';
    # update geoip DB once a week
    Mojo::IOLoop->timer(7 * 24 * 3600 => sub { $self->$updateGeoIP });
};

sub register {
    my $self = shift;
    my $app  = shift;

    $self->SUPER::register($app);

    $geoipDB = $self->datadir . '/GeoIP.dat';
    $pkgDB   = $self->datadir . '/' . $self->name . '.db';

    $self->$updateGeoIP;
    $self->$refreshDB;
}

sub process {
    my $c = shift;
    my $t = $c->param('text') || '0';

    $c->render(json => $c->app->$getPkgStat($t));
}

sub cleanup {
    kill SIGTERM, $pid if $pid;
}

1;

