package OOCEapps::Controller::PkgDep;
use Mojo::Base 'OOCEapps::Controller::base';

use Mojo::File;
use Mojo::JSON qw(decode_json);

# attributes
has pkgDB => sub { shift->config->{pkgDB} };

#private methods
my $getPkgDep = sub {
    my $self = shift;
    my $pkg  = shift;

    return OOCEapps::Mattermost->error('No package FMRI specified.') if !$pkg;

    # load db
    my $db = decode_json(Mojo::File->new($self->pkgDB)->slurp);

    my $fmri;
    my $none;
    for my $elem (keys %$db) {
        next if $elem !~ /$pkg$/i;

        $fmri = $elem;
        if (!@{$db->{$fmri}}) {
            $none = 1;

            next;
        }
        $none = 0;

        last;
    }

    return OOCEapps::Mattermost->error("No package found matching FMRI '$pkg'") if !$fmri;
    return OOCEapps::Mattermost->text("No packages depend on '$fmri'") if $none;

    my @text = ("The following packages depend on `$fmri`:");
    push @text, "- $_\n" for sort @{$db->{$fmri}};

    OOCEapps::Mattermost->table(\@text);
};

sub process {
    my $c = shift;
    my $p = $c->param('text');

    $c->checkToken;
    $c->render(json => $c->$getPkgDep($p));
}

1;

__END__

=head1 COPYRIGHT

Copyright 2022 OmniOS Community Edition (OmniOSce) Association.

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

2022-03-20 had Initial Version

=cut

