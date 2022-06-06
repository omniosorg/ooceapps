package OOCEapps::Model::PkgDep;
use Mojo::Base 'OOCEapps::Model::base';

use POSIX qw(SIGTERM);
use File::Spec;
use IPC::Open3;
use Time::Piece;
use Time::Seconds qw(ONE_MINUTE ONE_DAY);
use Mojo::Exception;
use Mojo::JSON qw(decode_json);

# constants
my $PKGREPO = '/usr/bin/pkgrepo';

# attributes
has schema  => sub {
    my $sv = shift->utils;

    return {
        repo_url  => {
            array       => 1,
            description => 'URL to repositories',
            example     => 'https://pkg.omnios.org/bloody/core',
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

has dbrefint => ONE_DAY;

#private methods
my $getPkgDep = sub {
    my $self = shift;

    my %pkgs;
    for my $repo (@{$self->config->{repo_url}}) {
        open my $pkgrepo, '-|', ($PKGREPO, qw(list -F json -s), $repo, '*@latest')
            or Mojo::Exception->throw("ERROR: executing pkgrepo: $!\n");

        my $json = decode_json(<$pkgrepo>);
        close $pkgrepo;

        for my $pkg (@$json) {
            open my $devnull, '>', File::Spec->devnull;
            my $pid = open3(undef, my $stdout, $devnull,
                $PKGREPO, qw(contents -m -t depend -s), $repo, "$pkg->{name}\@latest"),
                    or Mojo::Exception->throw("ERROR: executing pkgrepo: $!\n");

            # map to hash table to make entries unique
            my %deps = map { $_ => undef }
                map { m!^depend\s+fmri=(?:pkg:/(?:/[^/]+/)?)?([^@\s]+)! } (<$stdout>);

            waitpid $pid, 0;
            $pkgs{$pkg->{name}} = [ keys %deps ];
        }
    }

    my %deps = map { $_ => [] } keys %pkgs;
    for my $pkg (keys %pkgs) {
        push @{$deps{$_}}, $pkg for @{$pkgs{$pkg}};
    }

    # save db
    $self->utils->saveDB($self->config->{pkgDB}, \%deps);
};

my $refreshDB;
$refreshDB = sub {
    my $self = shift;

    # set next refresh in 1d + a maximum random 5 minutes
    Mojo::IOLoop->timer($self->dbrefint + int (rand (5 * ONE_MINUTE)) => sub { $self->$refreshDB });

    # only run refresh in one worker process
    return if -f $self->config->{pkgDB}
        && time - (stat $self->config->{pkgDB})[9] < $self->dbrefint;
    utime undef, undef, $self->config->{pkgDB};

    my $proc = Mojo::IOLoop->subprocess(
        sub {
            my $subprocess = shift;
            $self->$getPkgDep;
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

    $self->config->{pkgDB} = $self->datadir . '/' . $self->name . '.db';
    $self->config->{pid}   = 0;

    $self->$refreshDB;
}

sub DESTROY {
    my $self = shift;

    kill SIGTERM, $self->config->{pid} if $self->config->{pid};
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

2022-03-20 had Initial Version

=cut

