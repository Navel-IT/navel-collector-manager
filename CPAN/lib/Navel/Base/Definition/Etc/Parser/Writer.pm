# Copyright 2015 Navel-IT
# Navel Scheduler is developed by Yoann Le Garff, Nicolas Boquet and Yann Le Bras under GNU GPL v3

#-> BEGIN

#-> initialization

package Navel::Base::Definition::Etc::Parser::Writer;

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

sub write {
    my ($self, $file_path, $definitions) = @_;

    if (hascontent($file_path)) {
        write_file(
            $file_path,
            encode_json_pretty($definitions)
        );

        return $self;
    }

    croak('file path missing');
}

# sub AUTOLOAD {}

# sub DESTROY {}

1;

#-> END

__END__

=pod

=head1 NAME

Navel::Base::Definition::Etc::Parser::Writer

=head1 AUTHOR

Yoann Le Garff, Nicolas Boquet and Yann Le Bras

=head1 LICENSE

GNU GPL v3

=cut
