package Fenix::Model::Handler::Help;
use Mojo::Base 'Fenix::Model::Handler::base', -signatures;

use Mojo::Promise;

# default handler, lowest priority.
# if we get mentioned but don't know what to do we
# DM the user information about our capabilities
has priority => 9999;
has generic  => 0;
has dm       => 1;

sub process_p($self, $chan, $from, $msg, $mentioned = 0) {
    return undef if !$mentioned || $self->utils->muted(\$self->mutemap->{help}, $from);

    my $preface = $msg =~ /\bhelp\b/i
        ? "Hi $from, I am glad you asked!\n"
            . 'To get my attention, just mention my name in a message to the channel.'
        : "Hi $from, it seems that you tried to get my attention.\n"
            . 'However, I am afraid I did not understand your request.';

    return Mojo::Promise->resolve([ split /\n/, <<"END" ]);
$preface
I can look up Redmine issues with 'illumos <issue>', 'issue <issue>' or '#<issue>'
For SmartOS issues, use the issue type and number together, e.g. OS-1234.
I will look up GitHub commits if you ask with '<org|user>/<repository>#<commit_hash>'.
I can also find IPDs - 'IPD123', 'IPD-123' or 'IPD 123'
as well as OpenSolaris issues with a seven digit bug ID. If you want me to, I can also
dig very deeply and find stuff in the OpenSolaris ARC Material Archive, just use e.g. FWARC/2004/510.
Finally, if you post a link to a Redmine issue or Gerrit review, I'll fill in some more details.
END

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

2021-01-08 had Initial Version

=cut
