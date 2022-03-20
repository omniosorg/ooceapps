package OOCEapps::Mattermost;
use Mojo::Base -base;

# constants
my %OPTMAP = map { $_ => undef } qw(response_type goto_location username);

my $prepJSON = sub {
    my $text = shift;
    my $opts = shift // {};

    my $reply = { map { $_ => $opts->{$_} } grep { exists $OPTMAP{$_} } keys %$opts };

    $reply->{response_type} = 'in_channel' if !exists $reply->{response_type};

    $reply->{text} = $text;

    return $reply;
};

sub error {
    my $self = shift;

    return $prepJSON->(shift . "\n# :panic:", shift);
}

sub text {
    my $self = shift;

    return $prepJSON->(shift, shift);
}

sub code {
    return shift->text("```\n" . shift . "\n```", shift);
}

sub table {
    my $self  = shift;
    my $table = shift;
    my $opts  = shift;

    my $text = join "\n", map { ref $_ eq ref []
        ? ('| ' . (join ' | ', @$_) . ' |') : $_ } @$table;
    
    return $prepJSON->($text, $opts);
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

2017-09-06 had Initial Version

=cut

