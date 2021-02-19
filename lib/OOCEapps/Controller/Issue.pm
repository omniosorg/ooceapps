package OOCEapps::Controller::Issue;
use Mojo::Base 'OOCEapps::Controller::base';

use Text::ParseWords qw(shellwords);
use Mojo::JSON qw(decode_json);
use Mojo::File;
use OOCEapps::Mattermost;

#attributes
has issueDB => sub { shift->config->{issueDB} };
has fields  => sub { [ qw(project status author desc) ] };
has usage   => sub { OOCEapps::Mattermost->code(<< 'END'
Usage:
    /issue command [options...]

    where 'command' is one of the following:

        <ISSUE_ID>

        search <search_string>

        help
END
)};

my $createTable = sub {
    my $self = shift;
    my $data = shift // [];

    my @data;
    push @data, [ qw(Issue Project Status Author Description) ];
    push @data, [ qw(:---- :------ :----- :----- :----------) ];

    for my $issue (@$data) {
        push @data, [
            "[$issue->{id}]($issue->{url})",
            map { $issue->{$_} // '' } @{$self->fields}
        ];
    }

    return \@data;
};

my $search = sub {
    my $self  = shift;
    my $query = shift // '';
    my $db    = shift // {};
    my $field = shift // 'id';

    my @data;
    # we are most interested in the most recent issues
    for my $issue (reverse sort keys %$db) {
        next if $db->{$issue}->{$field} !~ /$query/i;

        push @data, $db->{$issue};
        # limit output to 20 lines for now
        last if $#data >= 20;
    }

    return \@data;
};

my $getIssue = sub {
    my $self = shift;
    my @p    = shellwords(shift // '');

    return $self->usage if $#p < 0 || $p[0] eq 'help';

    # load db
    my $DB = decode_json(Mojo::File->new($self->issueDB)->slurp)
        or return OOCEapps::Mattermost->error('DB cannot be opened. Try again later.');

    my $mainOpt = shift @p;
    for ($mainOpt) {
        /^search$/ && do {
            my $query = shift @p;
            my $tbl   = $self->$search($query, $DB, 'desc');

            return OOCEapps::Mattermost->error("No issue matching description: '$query'.") if !@$tbl;

            return OOCEapps::Mattermost->table($self->$createTable($tbl));
        };

        # default is to use argument to match an issue ID
        my $tbl = $self->$search($mainOpt, $DB);

        return OOCEapps::Mattermost->error("Could not find issue matching: '$mainOpt'.") if !@$tbl;

        return OOCEapps::Mattermost->table($self->$createTable($tbl));
    }

    # not reached
};

sub process {
    my $c = shift;
    my $p = $c->param('text');

    $c->checkToken;
    $c->render(json => $c->$getIssue($p));
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

