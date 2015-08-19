# Copyright 2015 Navel-IT
# Navel Scheduler is developed by Yoann Le Garff, Nicolas Boquet and Yann Le Bras under GNU GPL v3

#-> BEGIN

#-> initialization

package Navel::Base::Definition::Parser::Reader;

use strict;
use warnings;

use parent 'Navel::Base';

use Carp 'croak';

use File::Slurp;

use Navel::Utils 'decode_json';

our $VERSION = 0.1;

#-> methods

sub read {
    my ($self, $file_path) = @_;

    croak('file path missing') unless (defined $file_path);

    eval {
        decode_json(
            scalar read_file(
                $file_path,
                binmode => ':utf8'
            )
        );
    };
}

# sub AUTOLOAD {}

# sub DESTROY {}

1;

#-> END

__END__

=pod

=head1 NAME

Navel::Base::Definition::Parser::Reader

=head1 AUTHOR

Yoann Le Garff, Nicolas Boquet and Yann Le Bras

=head1 LICENSE

GNU GPL v3

=cut
