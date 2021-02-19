package OOCEapps::Issue::Joyent;
use Mojo::Base 'OOCEapps::Issue::base';

use Mojo::Promise;

has url => sub { Mojo::URL->new('https://smartos.org/bugview/index.html') };

my $getMaxId = sub {
    my $self = shift;

    my $tx = $self->ua->get($self->url);

    return -1 if !$tx->result->is_success;

    my ($maxId) = $tx->result->dom->find('body > div[class=container] > div')
        ->first->text =~ /of\s+(\d+)/;

    return $maxId;
};

my $parseEntries = sub {
    my $self = shift;
    my $tx   = shift;
    my $res  = $tx->result;

    my %data;
    for ($res->dom->find('tbody > tr')->each) {
        my $issue = $_->find('td');

        my $id     = $issue->[0]->find('a:first-child');
        my $idText = $id->first->text;
        my $idURL  = $id->map(sub { $self->url->new($_->{href})->to_abs($self->url) })->first->to_string;
        # adding the ID as a key (for searching) and value (for later usage)
        $data{$idText} = {
            id      => $idText,
            project => 'SmartOS',
            url     => $idURL,
            status  => $issue->[1]->text,
            desc    => $issue->[2]->text,
        };
    }
    return \%data;
};

sub parseIssues {
    my $self = shift;
    my $maxId = $self->$getMaxId;

    my $db = {};

    return $db if $maxId < 0;

    $self->ua->max_redirects(8)->connect_timeout(16)->request_timeout(24);

    Mojo::Promise->all(
        map {
            $self->ua->get_p($self->url->clone->query('offset=' . $_ * 50))->catch(sub { })
        } (0 .. int ($maxId / 50))
    )->then(sub {
        my @tx = @_;

        $_->[0]->result->is_success && do {
            $db = { %$db, %{$self->$parseEntries($_->[0])} }
        } for @tx;
    })->wait;

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

S<Dominik Hassler E<lt>hadfl@omnios.orgE<gt>>

=head1 HISTORY

2018-05-04 had Initial Version

=cut

