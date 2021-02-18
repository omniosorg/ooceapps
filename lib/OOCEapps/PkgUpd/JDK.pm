package OOCEapps::PkgUpd::JDK;
use Mojo::Base 'OOCEapps::PkgUpd::base';

# public methods
sub canParse {
    my $self = shift;
    my $name = shift;
    my $url  = shift;

    return $name =~ m|^runtime/java/openjdk|;
}

sub getVersions {
    my $self = shift;
    my $name = shift;
    my $res  = shift;

    $name = $self->extractName($name);

    ($name, my $ver) = $name =~ /^(\D+)(\d+)$/;

    my @vers = $res->dom->find('a')->each;
    my @gavers;

    if ($ver < 10) {
        for (my $i = 0; $i < @vers; $i++) {
            my ($upd) = $vers[$i] =~ /jdk${ver}u(\d+)-ga/
                or next;

            my ($bld) = $vers[++$i] =~ /jdk${ver}u${upd}-b(\d+)/
                or next;

            push @gavers, "1.$ver.$upd-$bld";
        }

        return \@gavers;
    }

    for (my $i = 0; $i < @vers; $i++) {
        my ($upd) = $vers[$i] =~ /jdk-$ver\.0\.(\d+)-ga/
            or next;

        my ($vers) = $vers[++$i] =~ /jdk-($ver\.0\.$upd\+\d+)/
            or next;

        push @gavers, $vers;
    }

    return \@gavers;
}

1;

__END__

=head1 COPYRIGHT

Copyright 2020 OmniOS Community Edition (OmniOSce) Association.

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

2017-09-06 had Initial Version

=cut

