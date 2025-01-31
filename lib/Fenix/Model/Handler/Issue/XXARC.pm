package Fenix::Model::Handler::Issue::XXARC;
use Mojo::Base 'Fenix::Model::Handler::Issue::base', -signatures;

use File::Temp;
use Mojo::File;
use Mojo::URL;
use Text::CSV;

# attributes
has priority => 9;
has baseurl  => sub { Mojo::URL->new('https://illumos.org') };
has issuestr => sub { 'OpenSolaris ARC Material Archive' };

# issue should be called first in 'process'.
# It parses the message and checks whether it is the correct handler
# return either an array ref of valid URLs or an empty array
sub issues($self, $msg) {
    my $baseurl = $self->baseurl->to_string;
    my $urlre   = qr§\b\Q$baseurl\E/opensolaris/ARChive/((?:FW|LS|PS|WS)ARC/\d{4}/\d{3})/§;
    for ($msg) {
        return ([ /$urlre/g ], { url => 1 }) if /$urlre/;
        return [ /\b((?:FW|LS|PS|WS)ARC(?:\s+|\/)\d{4}(?:\s+|\/)\d{3})\b/ig ];
    }

    return [];
}

sub issueURL($self, $issue) {
    return Mojo::URL->new('/opensolaris/ARChive/case_status.csv')->base($self->baseurl)->to_abs;
}

sub processIssue($self, $issue, $res) {
    $issue =~ s!\s+!/!g;
    $issue = uc $issue;

    my $file = Mojo::File->new(File::Temp->new);
    $res->save_to($file);

    open my $fh, '<', $file->to_string
        or return "'$issue' not found in " . $self->issuestr . '...';

    my $csv = Text::CSV->new;

    my %data;
    while (my $r = $csv->getline($fh)){
        next if $issue ne "$r->[0]/$r->[1]/$r->[2]";

        %data = (
            state  => $r->[3],
            status => $r->[4],
            name   => $r->[5],
        );

        last;
    }

    return "'$issue' not found in " . $self->issuestr . '...' if !%data;

    return {
        id       => $self->issuestr . " $issue",
        subject  => $data{name},
        url      => [
            $data{state} ne 'Unpublished'
                ? Mojo::URL->new("/opensolaris/ARChive/$issue/index.html")->base($self->baseurl)->to_abs
                : ()
        ],
        status   => $data{state},
        map { $_ => '' } qw(author assigned_to),
    };
}

1;

__END__

=head1 COPYRIGHT

Copyright 2024 OmniOS Community Edition (OmniOSce) Association.

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

2022-10-04 had Initial Version

=cut
