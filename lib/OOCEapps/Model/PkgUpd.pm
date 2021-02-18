package OOCEapps::Model::PkgUpd;
use Mojo::Base 'OOCEapps::Model::base';

use OOCEapps::Controller::PkgUpd;
use OOCEapps::Utils;

# constants
my $MODULES = join '::', grep { !/^Model$/ } split /::/, __PACKAGE__;

# attributes
has schema  => sub {
    my $sv = shift->utils;

    return {
        repos   => {
            members => {
                '^\S+'  => {
                    regex       => 1,
                    description => 'url to package list',
                    example     => 'https://raw.githubusercontent.com/omniosorg/omnios-build/master/doc/packages.md',
                    validator   => $sv->regexp(qr/^.*$/, 'expected a string'),
                },
            },
        },
        default => {
            description => 'when no repo is selected use this as default',
            example     => '"default" : "core"',
            validator   => sub {
                my $repo   = shift;
                my $parent = shift;

                return exists $parent->{repos}->{$repo} ? undef
                    : "repo called '$repo' is not configured"
            },
        },
        token   => {
            optional    => 1,
            description => 'Mattermost token',
            example     => 'abcd1234',
            validator   => $sv->regexp(qr/^\w+$/, 'expected an alphanumeric string'),
        },
    }
};

sub refreshParser {
    my $self = shift;

    my %packages = map { $_ => $self->getPkgList($_) } keys %{$self->config->{repos}};
    my $modules  = OOCEapps::Utils::loadModules($MODULES);

    for my $repo (keys %{$self->config->{repos}}) {
        PKG: for my $pkg (keys %{$packages{$repo}}) {
            for my $mod (@$modules) {
                $mod->canParse($pkg, $packages{$repo}->{$pkg}->{url}) && do {
                    $self->config->{parser}->{$pkg} = $mod;
                    next PKG;
                };
            }
        }
    }
    # default parser
    $self->config->{parser}->{DEFAULT} = OOCEapps::PkgUpd::base->new;
}

sub getPkgList {
    my $self = shift;
    my $repo = shift || $self->config->{default};

    return {} if !exists $self->config->{repos}->{$repo};

    my $tx = $self->ua->get($self->config->{repos}->{$repo});
    return {} if !$tx->result->is_success;

    my %pkgs;

    for (split /[\r\n]+/, $tx->result->body) {
        # | pkg | version | url [xurl] | notes
        my ($name, $version, $url, $xurl, $notes)
            = /^\s*\|
              \s*([^\s|]+)\s*\|             # pkg
              \s*(\d[^\s|]+)\s*\|           # version
              \s*([^\s|]+)\s*([^\s|]*)\s*   # url [xurl]
              (?:\|(.*))?/x or next;        # notes

        # skip packages which are labelled 'github-latest'
        next if $version =~ /^github-latest/;

        $pkgs{$name} = {
            version => $version,
            url     => $url,
            xurl    => $xurl // '',
            notes   => $notes // '',
        };
    }
    return \%pkgs;
}

sub register {
    my $self = shift;
    my $app  = shift;

    $self->SUPER::register($app);

    $self->refreshParser;
}

1;

__END__

=head1 COPYRIGHT

Copyright 2020 OmniOS Community Edition (OmniOSce) Association.

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

