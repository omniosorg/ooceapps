package OOCEapps::Model::RelSuffix;
use Mojo::Base 'OOCEapps::Model::base';

use OOCEapps::Utils;

# attributes
has schema  => sub {
    my $sv = OOCEapps::Utils->new;

    return {
    members => {
        'r1510\d\d' => {
            regex       => 1,
            description => 'release date',
            example     => '2017-05-22',
            validator   => $sv->regexp(qr/\d{4}-\d{1,2}-\d{1,2}/, 'not a valid ISO date'),
        },
    },
    }
};

1;

