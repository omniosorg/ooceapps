package OOCEapps::Utils;
use Mojo::Base -base;

use Mojo::JSON qw(encode_json decode_json);
use Mojo::Util qw(b64_encode b64_decode encode decode);
use Crypt::Ed25519;
use File::Spec qw(catdir splitpath);
use Email::MIME;
use Email::Sender::Simple;
use File::Temp;
use File::Copy;
use Time::Piece;
use Time::Seconds;
use Data::Dumper; # don't remove, not used for debugging only!

my %DEF_MAILATTR = (
    mail => {
        content_type => 'text/plain',
        disposition  => 'inline',
        encoding     => 'quoted-printable',
        charset      => 'UTF-8',
    },
    attach => {
        content_type => 'text/plain',
        disposition  => 'attachment',
        encoding     => 'base64',
    },
);

# private methods
my $dump = sub {
    my $dumper = Data::Dumper->new([ shift ]);
    $dumper->Sortkeys(1);

    return $dumper->Dump;
};

my $fixMIMEheader = sub {
    my $mimeparts = shift;
    for my $mime (@$mimeparts) {
        my $headers = $mime->{header}->{headers};
        for (my $i = $#$headers; $i >= 0; $i--) {
            $headers->[$i] =~ /^(?:MIME-Version|Date)$/
                && splice @$headers, $i, 2;
        }
    }
};

# static methods
=head2 pack($hash, $sec_key)

#pack the content of the hash, adding a timestamp and a signature
#in the process. Returns a b64 encoded string.

#The sec_key is generated with C<Crypt::Ed25519::eddsa_secret_key>.

=cut

sub pack {
    my $data    = shift;
    my $sec_key = shift;

    $data = { %$data };
    # add a timestamp guard against replay attacks
    $data->{__timestamp__} = time;

    # add a nonce to to make sure the signature
    # is different every time around
    $data->{__nonce__} = rand;

    # make sure we end up with a regular text string
    # to build the signature on and not something encoded
    my $content = encode 'UTF-8', $dump->($data);

    $data->{__signature__} = b64_encode(Crypt::Ed25519::eddsa_sign(
        $content, Crypt::Ed25519::eddsa_public_key($sec_key), $sec_key), q{});

    return b64_encode(encode_json($data), q{});
}

=head2 unpack($b64string, $pub_key[, $validity])

unpack the given string, checking the timestamp (for maximum age),
the signature vor validity and the presence of a nonce.
if anything fails, the method dies.

The pub_key is generated with C<Crypt::Ed25519::eddsa_public_key $sec_key>.

How old can a data pack be to be considered valid.

=cut

sub unpack {
    my $data      = decode_json(b64_decode(shift));
    my $pub_key   = shift;
    my $validity  = shift;
    my $signature = b64_decode(delete $data->{__signature__}) // die "invalid packege 2";

    # first remove the signature then walk the remaining data
    # to get the basis to check the signature
    my $content = encode 'UTF-8', $dump->($data);

    # finally remove the other bits that were added
    # in the pack routine above
    my $nonce = delete $data->{__nonce__} // die "invalid package 3";
    my $ts    = delete $data->{__timestamp__} // die "invalid package 1";

    Crypt::Ed25519::eddsa_verify($content, $pub_key, $signature)
        or die "invalid package 4";

    my $now = time;
    $validity && $now - $ts > $validity
        and die "invalid package 5 now:$now - ts:$ts >= $validity";

    return $data;
}

sub sendMail {
    my $to     = shift;
    my $from   = shift;
    my $subj   = shift // '';
    my $mail   = shift // {};
    my $attach = shift // [];
    my $header = shift // {};

    # use a local copy
    my $attr = { %$mail };
    my $body = delete $attr->{body} // '';
    $attr->{$_} //= $DEF_MAILATTR{mail}->{$_} for keys %{$DEF_MAILATTR{mail}};

    my $mimeparts = [
        Email::MIME->create(
            attributes => $attr,
            body       => $body,
        ),
        map {
            # use local copy
            $attr = { %$_ };
            $body = delete $attr->{body};
            $attr->{$_} //= $DEF_MAILATTR{attach}->{$_} for keys %{$DEF_MAILATTR{attach}};

            Email::MIME->create(
                attributes => $attr,
                body       => $body,
            )
        } @$attach,
    ];

    # Email::MIME::create always adds MIME-Version and Date headers
    # which should not be present in sub-parts. Email::MIME does not
    # provide a method to remove headers so we need this hack.
    $fixMIMEheader->($mimeparts);

    # no vertical whitespaces in subject
    $subj =~ s/[\r\n]+/ /g;
    # remove leading and trailing whitespaces
    $subj =~ s/^\s+|\s+$//g;

    my %toHdr = ref $to eq 'HASH'
        ? map { ucfirst ($_) => $to->{$_} } grep { /^(?:to|cc)$/ } keys %$to
        : ( To => $to );

    my $message = Email::MIME->create(
        header => [
            From    => $from,
            %toHdr,
            Subject => $subj,
            %$header,
        ],
        parts => $mimeparts,
    );

    Email::Sender::Simple->send($message, { to => $to->{bcc} })
        if ref $to eq 'HASH' && $to->{bcc};
    Email::Sender::Simple->send($message)
        if !(ref $to eq 'HASH' && $to->{bcc_only});
}

sub addMonths {
    my $time = Time::Piece->new(shift);

    return (($time - ($time->mday - 1) * ONE_DAY)->add_months(shift // 0))->epoch;
}

# public methods
sub loadModules {
    my $modules = shift;

    my @modules;
    for my $path (@INC) {
        my @mDirs = split /::|\//, $modules;
        my $fPath = File::Spec->catdir($path, @mDirs, '*.pm');
        for my $file (sort glob($fPath)) {
            my ($volume, $modulePath, $moduleName) = File::Spec->splitpath($file);
            $moduleName =~ s/\.pm$//;
            next if $moduleName eq 'base';

            my $module = do {
                require $file;
                ($modules . '::' . $moduleName)->new;
            };
            push @modules, $module if $module;
        }
    }

    return \@modules;
};

sub saveDB {
    my $self = shift;
    my $file = shift;
    my $db   = shift // {};

    my $fh = File::Temp->new(UNLINK => 0);
    print $fh encode_json $db;
    close $fh;

    move($fh->filename, $file);
}

sub file {
    my $self = shift;
    my $op   = shift;
    my $msg  = shift;

    return sub {
        my $file = shift;
        return open (my $fh, $op, $file) ? undef : "$msg '$file': $!";
    }
}

sub dir {
    my $self = shift;
    my $msg  = shift;

    return sub {
        my $dir = shift;
        return -d $dir ? undef : "$msg '$dir': $!";
    }
}

sub exe {
    my $self = shift;
    my $msg  = shift;

    return sub {
        my $exe = shift;
        return -x $exe ? undef : "$msg '$exe': $!";
    }
}

sub regexp {
    my $self = shift;
    my $rx   = shift;
    my $msg  = shift;

    return sub {
        my $value = shift;
        return $value =~ /$rx/ ? undef : "$msg ($value)";
    }
}

sub elemOf {
    my $self = shift;
    my $elems = [ @_ ];

    return sub {
        my $value = shift;
        return (grep { $_ eq $value } @$elems) ? undef
            : 'expected a value from the list: ' . join(', ', @$elems);
    }
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
S<Tobias Oetiker E<lt>tobi@omniosce.orgE<gt>>

=head1 HISTORY

2017-09-06 had Initial Version
2018-01-28 to Added Crypt Tools

=cut

