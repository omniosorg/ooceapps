package Fenix::Utils;
use Mojo::Base -base, -signatures;

use Mojo::Loader qw(find_modules load_class);
use IRC::Utils qw(parse_user);
use Time::Piece;

# attributes
has muteInt => 120; # default mute interval

# public methods
sub loadModules($self, $modprefix, %args) {
    my %modules;
    for my $module (grep { !/base$/ } find_modules $modprefix) {
        next if load_class $module;

        my $name = lc ((split /::/, $module)[-1]);
        $modules{$name} = $module->new(%args);
    }
    return \%modules;
}

sub from($self, $prefix) {
    return parse_user($prefix);
}

sub muted($self, $parentRef, $key) {
    return 1 if exists $$parentRef->{$key};

    $$parentRef->{$key} = undef;
    Mojo::IOLoop->timer($self->muteInt => sub { delete $$parentRef->{$key} });

    return 0;
}

1;

__END__

=head1 COPYRIGHT

Copyright 2021 OmniOS Community Edition (OmniOSce) Association.

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

2021-01-08 had Initial Version

=cut
