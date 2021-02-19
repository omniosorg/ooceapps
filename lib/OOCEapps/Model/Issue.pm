package OOCEapps::Model::Issue;
use Mojo::Base 'OOCEapps::Model::base';

use POSIX qw(SIGTERM);
use File::stat;
use OOCEapps::Utils;

# constants
my $MODULES = join '::', grep { !/^Model$/ } split /::/, __PACKAGE__;

# attributes
has schema  => sub {
    my $sv = shift->utils;

    return {
        token => {
            optional    => 1,
            description => 'Mattermost token',
            example     => 'abcd1234',
            validator   => $sv->regexp(qr/^\w+$/, 'expected an alphanumeric string'),
        },
    }
};

has issueModules => sub { OOCEapps::Utils::loadModules($MODULES) };

has dbrefint => 3600;

my $parseIssues = sub {
    my $self = shift;

    my $db = {};
    $db = { %$db, %{$_->parseIssues} } for @{$self->issueModules};

    $self->utils->saveDB($self->config->{issueDB}, $db);
};

my $refreshDB;
$refreshDB = sub {
    my $self = shift;

    # set next refresh in 1h + a maximum random 5 minutes
    Mojo::IOLoop->timer($self->dbrefint + int (rand (300)) => sub { $self->$refreshDB });

    # only run refresh in one worker process
    return if -f $self->config->{issueDB}
        && time - stat ($self->config->{issueDB})->mtime < $self->dbrefint;
    utime undef, undef, $self->config->{issueDB};

    my $proc = Mojo::IOLoop->subprocess(
        sub {
            my $subprocess = shift;
            $self->$parseIssues;
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

    $self->config->{issueDB} = $self->datadir . '/' . $self->name . '.db';
    $self->config->{pid}     = 0;

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

S<Dominik Hassler E<lt>hadfl@omnios.orgE<gt>>

=head1 HISTORY

2018-05-04 had Initial Version

=cut

