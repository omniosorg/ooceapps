package OOCEapps::Utils;
use Mojo::Base -base;

use File::Spec qw(catdir splitpath);

# public methods
sub loadModules {
    my $modules = shift;

    my @modules;
    for my $path (@INC) {
        my @mDirs = split /::|\//, $modules;
        my $fPath = File::Spec->catdir($path, @mDirs, '*.pm');
        for my $file (sort glob($fPath)) {
            my ($volume, $modulePath, $moduleName) = File::Spec->splitpath($file);
            $moduleName =~ s/\.pm$//;
            next if $moduleName eq 'base';

            my $module = do {
                require $file;
                ($modules . '::' . $moduleName)->new;
            };
            push @modules, $module if $module;
        }
    }

    return \@modules;
};

sub file {
    my $self = shift;
    my $op   = shift;
    my $msg  = shift;

    return sub {
        my $file = shift;
        return open (my $fh, $op, $file) ? undef : "$msg '$file': $!";
    }
}

sub dir {
    my $self = shift;
    my $msg  = shift;

    return sub {
        my $dir = shift;
        -d $dir ? undef : "$msg '$dir': $!";
    }
}

sub regexp {
    my $self = shift;
    my $rx   = shift;
    my $msg  = shift;

    return sub {
        my $value = shift;
        return $value =~ /$rx/ ? undef : "$msg ($value)";
    }
}

sub elemOf {
    my $self = shift;
    my $elems = [ @_ ];

    return sub {
        my $value = shift;
        return (grep { $_ eq $value } @$elems) ? undef
            : 'expected a value from the list: ' . join(', ', @$elems);
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

