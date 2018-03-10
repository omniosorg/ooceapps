package OOCEapps::Model::PkgStat;
use Mojo::Base 'OOCEapps::Model::base';

use POSIX qw(SIGTERM);
use Time::Piece;
use Geo::IP;
use Mojo::JSON qw(encode_json);
use IO::Uncompress::Gunzip qw(gunzip $GunzipError);
use File::Temp;
use File::Copy;
use OOCEapps::Utils;

# attributes
has schema  => sub {
    my $sv = OOCEapps::Utils->new;

    return {
        logdir    => {
            description => 'path to log files',
            example     => '/var/log/nginx',
            validator   => $sv->dir('cannot access directory'),
        },
        geoip_url => {
            description => 'url to geoip database',
            example     => 'http://geolite.maxmind.com/download/geoip/database/GeoLiteCountry/GeoIP.dat.gz',
            validator   => $sv->regexp(qr/^.*$/, 'expected a string'),
        },
        token     => {
            optional    => 1,
            description => 'Mattermost token',
            example     => 'abcd1234',
            validator   => $sv->regexp(qr/^\w+$/, 'expected an alphanumeric string'),
        },
    }
};

has dbrefint => 3600;

#private methods
my $updateGeoIP;
$updateGeoIP = sub {
    my $self   = shift;
    my $oneoff = shift;

    my $res = $self->ua->get($self->config->{geoip_url})->result;
    die "ERROR: downloading GeoIP database from '$self->config->{geoip_url}'\n"
        if !$res->is_success;

    my $fh = File::Temp->new(SUFFIX => '.gz');
    close $fh;
    my $filename = $fh->filename;
    $res->content->asset->move_to($filename);
    gunzip $filename => $self->config->{geoipDB}
        or die "ERROR: gunzip GeoIP failed: $GunzipError\n";

    unlink $filename;
    # update geoip DB once a week
    Mojo::IOLoop->timer(7 * 24 * 3600 => sub { $self->$updateGeoIP }) if !$oneoff;
};

my $seenInRel = sub {
    my $uuid   = shift;
    my $ip     = shift;
    my $relTbl = shift;

    # if UUID is not given (i.e. '-') check if the unique IP has been seen
    # otherwise check if the UUID has been seen
    return $uuid eq '-' ? exists $relTbl->{ips}->{$ip}
        : exists $relTbl->{uuids}->{$uuid};
};

my $parseFiles = sub {
    my $self  = shift;
    my $epoch = gmtime->epoch;
    my $data  = {};

    for my $logfile (glob $self->config->{logdir} . '/access*') {
        open my $fh, '<', $logfile or die "ERROR: opening file '$logfile': $!\n";

        while (<$fh>) {
            my ($ip, $ts, $rel, $uuid, $zone, $image)
                = m!^((?:\d{1,3}\.){3}\d{1,3})[^\[]+\[([^\]]+)\]\s+         # ip and ts
                    "(?:GET|HEAD)\s+/([^/]+)/core[^"]+"                     # release
                    (?:\s+\S+){2}\s+"[^"]+"\s+"pkg/[^"]+"                   # filter user agent
                    (?:\s+(-|[\da-f]{8}-(?:[\da-f]{4}-){3}[\da-f]{12})      # uuid
                    (?:(?:;|\s+)((?:non)?global)(?:,(full|partial))?)?)?!x  # zone and image
                    or next;

            # get how many days the entry is past
            my $days = int(($epoch - Time::Piece->strptime($ts, '%d/%b/%Y:%H:%M:%S %z')->epoch) / (24 * 3600)) + 1;

            # set defaults
            $uuid  //= '-';
            $zone  //= 'global';
            $image //= 'full';

            $data->{$_}->{$days}->{$ip}->{count}++ for ($rel, 'total');
            exists $data->{$_}->{$days}->{$ip}->{uuids}->{$uuid} || do {
                $data->{$_}->{$days}->{$ip}->{uuids}->{$uuid}->{$zone}  = 1;
                $data->{$_}->{$days}->{$ip}->{uuids}->{$uuid}->{$image} = 1;
            } for ($rel, 'total');
        }

        close $fh;
    }

    my $gip = Geo::IP->open($self->config->{geoipDB}, GEOIP_MEMORY_CACHE);
    my $db = {};
    my %seenTbl;

    for my $rel (keys %$data) {
        for my $day (sort { $a <=> $b } keys %{$data->{$rel}}) {
            for my $ip (keys %{$data->{$rel}->{$day}}) {
                my $country = $gip->country_name_by_addr($ip) or do {
                    # geoip database likely to be broken if we don't get a 'valid' country
                    # update geoip and skip this round of refreshing the statistics
                    $self->$updateGeoIP(1);
                    return;
                };

                $db->{$rel}->{$day}->{$country}->{unique}++
                    if !exists $seenTbl{$rel}->{ips}->{$ip};
                $db->{$rel}->{$day}->{$country}->{total}
                    += $data->{$rel}->{$day}->{$ip}->{count};

                $seenInRel->($_, $ip, $seenTbl{$rel}) || do {
                    my $uuid = $_;
                    $seenTbl{$rel}->{uuids}->{$uuid} = undef;

                    $db->{$rel}->{$day}->{$country}->{uuids}++;
                    $db->{$rel}->{$day}->{$country}->{$_}
                        += $data->{$rel}->{$day}->{$ip}->{uuids}->{$uuid}->{$_} // 0 for qw(global nonglobal);
                } for (keys %{$data->{$rel}->{$day}->{$ip}->{uuids}});

                $seenTbl{$rel}->{ips}->{$ip} = undef;
            }
        }
    }
    # add timestamp of statistics refresh
    $db->{update_ts} = gmtime;

    # save db
    my $fh = File::Temp->new(UNLINK => 0);
    print $fh encode_json $db;
    close $fh;

    move($fh->filename, $self->config->{pkgDB});
};

my $refreshDB;
$refreshDB = sub {
    my $self = shift;

    # set next refresh in 1h + a maximum random 5 minutes
    Mojo::IOLoop->timer($self->dbrefint + int (rand (300)) => sub { $self->$refreshDB });

    # only run refresh in one worker process
    return if -f $self->config->{pkgDB}
        && time - (stat $self->config->{pkgDB})[9] < $self->dbrefint;
    utime undef, undef, $self->config->{pkgDB};

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

sub DESTROY {
    my $self = shift;

    kill SIGTERM, $self->config->{pid} if $self->config->{pid};
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

