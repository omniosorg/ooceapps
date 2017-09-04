package OOCEapps::Model::PKGstat;
use Mojo::Base 'OOCEapps::Model::base';

use POSIX qw(SIGTERM);
use Time::Piece;
use Geo::IP::PurePerl;
use Mojo::JSON qw(encode_json);
use Mojo::UserAgent;
use IO::Uncompress::Gunzip qw(gunzip $GunzipError);

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

    my $gip = Geo::IP::PurePerl->new($self->config->{geoipDB}, GEOIP_MEMORY_CACHE);
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
    open my $fh, '>', $self->config->{pkgDB} . '.new'
        or die "ERROR: opening '" . $self->config->{pkgDB} . "' for writing: $!\n";
    print $fh encode_json $db;
    close $fh;

    rename $self->config->{pkgDB} . '.new', $self->config->{pkgDB};
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
            $self->config->{pid} = 0;
        }
    );

    $self->config->{pid} = $proc->pid;
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

    $res->content->asset->move_to($self->config->{geoipDB} . '.gz');
    gunzip $self->config->{geoipDB} . '.gz' => $self->config->{geoipDB}
        or die "ERROR: gunzip GeoIP failed: $GunzipError\n";

    unlink $self->config->{geoipDB} . '.gz';
    # update geoip DB once a week
    Mojo::IOLoop->timer(7 * 24 * 3600 => sub { $self->$updateGeoIP });
};

sub register {
    my $self = shift;
    my $app  = shift;

    $self->SUPER::register($app);

    $self->config->{geoipDB} = $self->datadir . '/GeoIP.dat';
    $self->config->{pkgDB}   = $self->datadir . '/' . $self->name . '.db';
    $self->config->{pid}     = 0;

    $self->$updateGeoIP;
    $self->$refreshDB;
}

sub cleanup {
    my $self = shift;

    kill SIGTERM, $self->config->{pid} if $self->config->{pid};
}

1;

