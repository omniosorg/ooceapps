package OOCEapps::Utils;
use Mojo::Base -base;
use Mojo::JSON qw(encode_json decode_json);
use Mojo::Util qw(b64_encode b64_decode encode decode);
use Crypt::Ed25519;

use File::Spec qw(catdir splitpath);

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

sub executable {
    my $self = shift;

    return sub {
        my $exe = shift;
        return -x $exe ? undef : "'$exe' is not an executable.";
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

=head2 pack($hash,$secret_key)

pack the content of the hash, adding a timestamp and a signature in the process. Returns a b64 encoded string.
The secret_key is generated with C<Crypt::Ed25519::eddsa_secret_key>.

=cut

my $dataWalker;

sub pack {
    my $self = shift;
    my $data = shift;
    my $secret_key = shift;
    $data = { %$data };
    # add a timestamp guard against replay attacks
    $data->{__timestamp__} = time;

    # add a nonce to to make sure the signature
    # is different every time around
    $data->{__nonce__} = rand;

    # make sure we end up with a regular text string
    # to build the signature on and not something encoded
    my $content = encode('UTF-8',$dataWalker->($data));

    $data->{__signature__} = b64_encode(Crypt::Ed25519::eddsa_sign($content,Crypt::Ed25519::eddsa_public_key $secret_key,$secret_key),'');
    return b64_encode(encode_json($data), "");
}

=head2 unpack($b64string,$public_key[,$pack_validity])

unpack the given string, checking the timestamp (for maximum age), the signature vor validity and the presence of a nonce.
if anything fails, the method dies.

The public_key is generated with C<Crypt::Ed25519::eddsa_public_key $secret_key>.

How old can a data pack be to be considered valid.

=cut

sub unpack {
    my $self = shift;
    my $json = b64_decode(shift);
    my $data = decode_json($json);
    my $public_key = shift;
    my $signature = b64_decode(delete $data->{__signature__}) // die "invalid packege 2";

    # first remove the signature then walk the remaining data
    # to get the basis to check the signature
    my $content = encode('UTF-8',$dataWalker->($data));

    # finally remove the other bits that were added
    # in the pack routine above
    my $nonce = delete $data->{__nonce__} // die "invalid package 3";
    my $timestamp = delete $data->{__timestamp__} // die "invalid package 1";
    my $now = time;
    if (Crypt::Ed25519::eddsa_verify $content, $public_key, $signature){
        if (not $packValidaity or $now - $timestamp < $packValidity ){
            return $data;
        }
        die "invalid package 5 now:$now - ts:$timestamp >= ".$packValidity;
    }
    die "invalid package 4";
}


$dataWalker = sub {
    my $data = shift;
    my $antiLoop = shift // {};
    for (ref $data){
        next if $antiLoop->{''.$data};
        $antiLoop->{''.$data} = 1;
        /ARRAY/ && return join "\n", map { $dataWalker->($_, $antiLoop) } @$data;
        /HASH/ &&  return join "\n", map { $dataWalker->($data->{$_}, $antiLoop) } sort keys %$data;
        /^$/ && return $data;
        die "Unknown data type '$_'";
    }
};

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

