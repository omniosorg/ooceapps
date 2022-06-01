package OOCEapps::PkgUpd::ISC;
use Mojo::Base 'OOCEapps::PkgUpd::base';

my %VERMAP = (
    bind => qr/9\.18\./,
);

# public methods
sub canParse {
    my $self = shift;
    my $name = shift;
    my $url  = shift;

    return $url =~ m|^https?://ftp\.isc\.org|
        || $url =~ m|https://downloads\.isc\.org/isc|;
}

sub getVersions {
    my $self = shift;
    my $name = shift;
    my $res  = shift;

    # remove isc- prefix
    $name =~ s/isc-//;
    ($name, my $ver) = $self->extractNameMajVer($name);
    my $mVer = $ver ne '.' ? qr/$ver/
        : $VERMAP{$name} // qr/\d+\./;

    return [
        grep { !/(?:rc|b)\d+$/ }
        map { $_->text =~ /^($mVer.*[^\/])/ }
        $res->dom->find('td.indexcolname a')->each
    ];
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

