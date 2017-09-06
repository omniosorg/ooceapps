package OOCEapps;
use Mojo::Base 'Mojolicious';

use FindBin;
use File::Basename qw(basename);
use File::Spec qw(catdir splitpath);
use Data::Processor;
use Mojo::JSON qw(decode_json);

# constants
my $MODULES = __PACKAGE__ . '::Model';
my $CONFILE = "$FindBin::RealBin/../etc/" . basename($0) . '.conf'; # CONFFILE
my $DATADIR = "$FindBin::RealBin/../var"; # DATADIR

# attributes
has modules => sub { [] };
has datadir => $DATADIR;
has config  => sub { {} };
has schema  => sub { { MODULES => { members => {} } } };

# private methods
my $loadModules = sub {
    my $app = shift;

    for my $path (@INC){
        my @mDirs = split /::/, $MODULES;
        my $fPath = File::Spec->catdir($path, @mDirs, '*.pm');
        for my $file (sort glob($fPath)) {
            my ($volume, $modulePath, $moduleName) = File::Spec->splitpath($file);
            $moduleName =~ s/\.pm$//;
            next if $moduleName eq 'base';

            my $module = do {
                require $file;
                ($MODULES . '::' . $moduleName)->new();
            };
            $module && do {
                $app->schema->{MODULES}->{members}->{$module->name}
                    = $module->schema;
                push @{$app->modules}, $module;
            };
        }
    }
};

# public methods
sub startup {
    my $app = shift;
    $app->$loadModules();

    # load config
    open my $fh, '<', $CONFILE or die "ERROR: opening config file '$CONFILE': $!\n";
    $app->config(decode_json do { local $/; <$fh> });
    close $fh;

    my $dp = Data::Processor->new($app->schema);
    my $ec = $dp->validate($app->config);
    $ec->count and die join ("\n", map { $_->stringify } @{$ec->{errors}}) . "\n";

    # set individual module config and register
    for my $module (@{$app->modules}) {
        $module->config($app->config->{MODULES}->{$module->name});
        $module->register($app);
    }
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

