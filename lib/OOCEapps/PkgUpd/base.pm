package OOCEapps::PkgUpd::base;
use Mojo::Base -base;

# public methods
sub canParse {
    my $self = shift;
    my $name = shift;
    my $url  = shift;

    # the subclass should implement a check if it can 'getVersions'
    # for $name and/or $url
    return 0;
}

sub extractName {
    my $self = shift;
    return (split /\//, shift)[-1];
}

sub extractNameMajVer {
    my $self = shift;

    my $name = $self->extractName(shift);

    my $ver = '.';
    $name =~ /^(\S+)-(\d+)$/ && do {
        $name = $1;
        $ver  = join '.', split //, $2, 2;
    };

	return ($name, $ver);
}

sub getVersions {
    my $self = shift;
    my $name = shift;
    my $res  = shift;

    my $ver;
    ($name, $ver) = $self->extractNameMajVer($name);

    return [
        grep { /^$ver/ }
        grep { !/alpha|beta|(?:rc|a|b)\w*\d+$/ }
        map { m!(?:\b|/|lib)$name-((?:\d{8}-)?(?:\d{1,7}\.){1,3}[^-.]+|\d+)(?:-source)?
            \.(?:tar\.(?:gz|xz|bz2|lz)|zip|tgz)!ix
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

S<Dominik Hassler E<lt>hadfl@omnios.orgE<gt>>

=head1 HISTORY

2017-09-06 had Initial Version

=cut

