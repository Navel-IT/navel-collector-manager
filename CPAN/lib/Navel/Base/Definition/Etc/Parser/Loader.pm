# Copyright 2015 Navel-IT
# Navel Scheduler is developped by Yoann Le Garff, Nicolas Boquet and Yann Le Bras under GNU GPL v3

#-> BEGIN

#-> initialization

package Navel::Base::Definition::Etc::Parser::Loader;

use strict;
use warnings;

use parent qw/
    Navel::Base
/;

use Carp qw/
    carp
    croak
/;

use String::Util qw/
    hascontent
/;

use File::Slurp;

use Navel::Utils qw/
    :all
/;

our $VERSION = 0.1;

#-> methods

sub load {
    my ($self, $file_path) = @_;

    if (hascontent($file_path)) {
            my $json = eval {
                decode_json(
                    scalar read_file($file_path)
                );
            };

            return $@ ? [0, 'JSON decode failed for file ' . $file_path . ' : ' . $@] : [1, $json];
    }

    croak('File path missing');
}

# sub AUTOLOAD {}

# sub DESTROY {}

1;

#-> END

__END__

=pod

=head1 NAME

Navel::Base::Definition::Etc::Parser::Loader

=head1 AUTHOR

Yoann Le Garff, Nicolas Boquet and Yann Le Bras

=head1 LICENSE

GNU GPL v3

=cut
