package OOCEapps::Model::RelSuffix;
use Mojo::Base 'OOCEapps::Model::base';

# attributes
has schema  => sub { {
    members => {
        'r1510\d\d' => {
            regex       => 1,
            description => 'release date',
            example     => '2017-05-22',
            validator   => sub { my $d = shift; $d =~ /\d{4}-\d{1,2}-\d{1,2}/ ? undef : "not a valid ISO date: '$d'" },
        },
    },
} };

1;

