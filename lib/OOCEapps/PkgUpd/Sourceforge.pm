package OOCEapps::PkgUpd::Sourceforge;
use Mojo::Base 'OOCEapps::PkgUpd::base';

my %TRANSFORMDIR = (
    libid3tag   => 'mad',
    freetype2   => 'freetype',
    libmcrypt   => 'mcrypt',
);

my %TRANSFORM = (
    freepascal  => 'Source',
);

# public methods
sub canParse {
    my $self = shift;
    my $name = shift;
    my $url  = shift;

    return $url =~ /sourceforge\.net/
        && $name !~ m|^compress/(?:un)?zip|
        && $name !~ m|^ooce/editor/joe$|
        && $name !~ m|^system/network/lldp$|
        && $name !~ m|^ooce/system/top$|;
}

sub getVersions {
    my $self = shift;
    my $name = shift;
    my $res  = shift;

    $name = $self->extractName($name);

    my $dirname = $TRANSFORMDIR{$name} // $name;
    $name = $TRANSFORM{$name} // $name;

    return [
        grep { !/(?:rc|release-?candidate|a(?:lpha)?|b(?:eta)?)\d+$/ }
        map {
            /$dirname\/files\/(?:$name[-\/])?
            (?:stable-[\d.x]+\/$name-)?([\d.-]+\d+\w*)/xi
        } $res->dom->find('a')->each
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

S<Dominik Hassler E<lt>hadfl@omniosce.orgE<gt>>

=head1 HISTORY

2017-09-06 had Initial Version

=cut

