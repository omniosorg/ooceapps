package OOCEapps;
use Mojo::Base 'Mojolicious';

use FindBin;
use File::Basename qw(basename);
use File::Spec qw(catdir splitpath);
use Data::Processor;
use Mojo::JSON qw(decode_json);
use Mojo::File;
use Mojo::Home;

# constants
my $MODULES = __PACKAGE__ . '::Model';
my $CONFFILE = $ENV{OOCEAPP_CONF} || Mojo::Home->new->rel_file("etc/ooceapps.conf")->to_string; # CONFFILE
my $DATADIR = "$FindBin::RealBin/../var"; # DATADIR

# attributes
my %loaded;
has model => sub {
    my %map;
    my $app = shift;

    for my $path (@INC){
        my @mDirs = split /::/, $MODULES;
        my $fPath = File::Spec->catdir($path, @mDirs, '*.pm');

        for my $file (sort glob($fPath)) {
            my ($volume, $modulePath, $moduleName) = File::Spec->splitpath($file);
            $moduleName =~ s/\.pm$//;

            next if $moduleName eq 'base';
            next if $ENV{OOCEAPP_SINGLE_MODULE} && $moduleName ne $ENV{OOCEAPP_SINGLE_MODULE};

            my $module = do {
                my $mod = $MODULES . '::' . $moduleName;
                if (not $loaded{$mod}){
                    require $file;
                    $loaded{$mod} = 1;
                }
                $mod->new(
                    app=>$app,
                );
            };
            $module && do {
                $app->schema->{MODULES}->{members}->{$module->name}
                    = $module->schema;
                $map{$module->name} = $module;
            };
        }
    }
    return \%map;
};

has datadir => $DATADIR;

has config  => sub {
    my $app = shift;
    # load config
    my $cfg = decode_json do { Mojo::File->new($CONFFILE)->slurp };

    my $dp = Data::Processor->new($app->schema);
    my $ec = $dp->validate($cfg);
    $ec->count and die join ("\n", map { $_->stringify } @{$ec->{errors}}) . "\n";
    return $cfg;
};

has schema  => sub { { MODULES => { members => {} } } };

# public methods
sub startup {
    my $app = shift;
    # set individual module config and register
    my $model = $app->model;
    for my $module (keys %{$model}) {
        $model->{$module}->register;
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
