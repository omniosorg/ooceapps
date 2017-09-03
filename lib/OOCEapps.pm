package OOCEapps;
use Mojo::Base 'Mojolicious';

use FindBin;
use File::Basename qw(basename);
use File::Spec qw(catdir splitpath);
use Data::Processor;
use Mojo::JSON qw(decode_json);

# constants
my $MODULES = __PACKAGE__ . '::Module';
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

sub DESTROY {
    $_->cleanup for @{shift->modules};
}

1;

