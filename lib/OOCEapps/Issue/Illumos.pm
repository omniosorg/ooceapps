package OOCEapps::Issue::Illumos;
use Mojo::Base 'OOCEapps::Issue::base';

has url => sub { Mojo::URL->new('https://www.illumos.org/issues') };

has fieldmap => sub {{
    id      => 0,
    project => 1,
    status  => 4,
    desc    => 6,
    author  => 7,
}};

sub parseIssues {
    my $self = shift;

    my $tx = $self->ua->get($self->url->new($self->url . '.csv')->query('columns=all'));

    my $db = {};
    return $db if !$tx->result->is_success;

    my @issues = split /[\r\n]+/, $tx->result->body;
    # drop header
    shift @issues;

    my $url = $self->url->to_string;
    for (@issues) {
        my @issue = split /,/;

        my $id  = $issue[$self->fieldmap->{id}];
        $db->{$id} = {
            url => "$url/$id",
            map { $_ => $issue[$self->fieldmap->{$_}] } keys %{$self->fieldmap}
        };
    }

    return $db;
}

1;

__END__

=head1 COPYRIGHT

Copyright 2018 OmniOS Community Edition (OmniOSce) Association.

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

2018-05-04 had Initial Version

=cut

