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

sub table {
    my $self  = shift;
    my $table = shift;
    my $opts  = shift;

    my $text = join "\n", map { ref $_ eq 'ARRAY'
        ? ('| ' . (join ' | ', @$_) . ' |') : $_ } @$table;
    
    return $prepJSON->($text, $opts);
}

1;

