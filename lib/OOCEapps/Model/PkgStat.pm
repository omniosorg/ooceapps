package OOCEapps::Model::PkgStat;
use Mojo::Base 'OOCEapps::Model::base';

use POSIX qw(SIGTERM);
use Time::Piece;
use MaxMind::DB::Reader;
use Mojo::JSON qw(encode_json);
use Archive::Tar;
use Regexp::IPv4 qw($IPv4_re);
use Regexp::IPv6 qw($IPv6_re);

# attributes
has schema  => sub {
    my $sv = shift->utils;

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

    my $fh = File::Temp->new(SUFFIX => 'tar.gz');
    close $fh;
    my $filename = $fh->filename;
    $res->content->asset->move_to($filename);

    my $tar = Archive::Tar->new;
    $tar->read($filename);
    my ($db) = grep { /mmdb$/ } $tar->list_files;
    $tar->extract_file($db, $self->config->{geoipDB})
        or die "ERROR: extracting GeoIP failed\n";

    unlink $filename;
    # update geoip DB once a week
    Mojo::IOLoop->timer(7 * 24 * 3600 => sub { $self->$updateGeoIP }) if !$oneoff;
};

my $seenInRel = sub {
    my $uuid   = shift;
    my $ip     = shift;
    my $relTbl = shift;

    # if UUID is not given (i.e. '-') we pretend to have seen it already so it gets ignored
    # otherwise check if the UUID has been seen
    return $uuid eq '-' || exists $relTbl->{uuids}->{$uuid};
};

my $parseFiles = sub {
    my $self  = shift;
    my $epoch = gmtime->epoch;
    my $data  = {};

    for my $logfile (glob $self->config->{logdir} . '/access*') {
        open my $fh, '<', $logfile or die "ERROR: opening file '$logfile': $!\n";

        while (<$fh>) {
            my ($ip, $ts, $rel, $uuid, $zone, $image)
                = m!^($IPv4_re|$IPv6_re)\s+[^\[]+\[([^\]]+)\]\s+            # ip and ts
                    "(?:GET|HEAD)\s+/([^/]+)/core[^"]+"                     # release
                    (?:\s+\S+){2}\s+"[^"]+"\s+"pkg/[^"]+"                   # filter user agent
                    (?:\s+(-|[\da-f]{8}-(?:[\da-f]{4}-){3}[\da-f]{12})      # uuid
                    (?:(?:;|\s+)((?:non)?global)(?:,(full|partial))?)?)?!x  # zone and image
                    or next;

            # filter releases to get rid of 'broken' requests
            next if $rel !~ /^(?:r1510\d\d|bloody)$/;

            # get how many days the entry is past
            my $days = int(($epoch - Time::Piece->strptime($ts, '%d/%b/%Y:%H:%M:%S %z')->epoch) / (24 * 3600)) + 1;

            # set defaults
            $uuid  //= '-';
            $zone  //= 'global';
            $image //= 'full';

            # exclude bloody from aggregated stats
            my @rels = ($rel, $rel eq 'bloody' ? () : qw(total));
            $data->{$_}->{$days}->{$ip}->{count}++ for @rels;
            exists $data->{$_}->{$days}->{$ip}->{uuids}->{$uuid} || do {
                $data->{$_}->{$days}->{$ip}->{uuids}->{$uuid}->{$zone}  = 1;
                $data->{$_}->{$days}->{$ip}->{uuids}->{$uuid}->{$image} = 1;
            } for @rels;
        }

        close $fh;
    }

    my $gip = MaxMind::DB::Reader->new(file => $self->config->{geoipDB});
    my $db = {};
    my %seenTbl;
    my $needGeoIPupdate = 0;

    for my $rel (keys %$data) {
        for my $day (keys %{$data->{$rel}}) {
            for my $ip (keys %{$data->{$rel}->{$day}}) {
                local $@;
                my $rec = eval {
                    local $SIG{__DIE__};
                    $gip->record_for_address($ip);
                };
                if ($@) {
                    # geoip database might be broken if we don't get a 'valid' record
                    # or the IP is not (yet) in the database. Anyway, update GeoIP
                    # and skip this IP for now.
                    $needGeoIPupdate = 1;
                    next;
                }
                my $country = $rec->{country}->{names}->{en} or next;

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
    $self->utils->saveDB($self->config->{pkgDB}, $db);

    $self->$updateGeoIP(1) if $needGeoIPupdate;
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

    $self->config->{geoipDB} = $self->datadir . '/GeoLite2-Country.mmdb';
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

Copyright 2019 OmniOS Community Edition (OmniOSce) Association.

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

2019-01-11 had Migration to GeoIP2
2017-09-06 had Initial Version

=cut

