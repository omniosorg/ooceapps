package OOCEapps::Model::Cowsay;
use Mojo::Base 'OOCEapps::Model::base';

use Acme::Cow;
use Acme::Cow::DragonAndCow;

# attributes
has schema  => sub {
    my $sv = shift->utils;

    return {
        token => {
            optional    => 1,
            description => 'Mattermost token',
            example     => 'abcd1234',
            validator   => $sv->regexp(qr/^\w+$/, 'expected an alphanumeric string'),
        },
    }
};

has cow    => sub { my $cow = Acme::Cow->new; $cow->wrap(80); return $cow; };
has dragon => sub { my $cow = Acme::Cow::DragonAndCow->new; $cow->wrap(80); return $cow; };

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

