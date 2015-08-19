# Copyright 2015 Navel-IT
# Navel Scheduler is developed by Yoann Le Garff, Nicolas Boquet and Yann Le Bras under GNU GPL v3

#-> BEGIN

#-> initialization

package Navel::Base::Definition::Parser::Writer;

use strict;
use warnings;

use parent 'Navel::Base';

use Carp 'croak';

use File::Slurp;

use Navel::Utils 'encode_json_pretty';

our $VERSION = 0.1;

#-> methods

sub write {
    my ($self, $file_path, $definitions) = @_;

    croak('file path missing') unless (defined $file_path);

    write_file(
        $file_path,
        {
            binmode => ':utf8'
        },
        \encode_json_pretty($definitions)
    );

    $self;
}

# sub AUTOLOAD {}

# sub DESTROY {}

1;

#-> END

__END__

=pod

=head1 NAME

Navel::Base::Definition::Parser::Writer

=head1 AUTHOR

Yoann Le Garff, Nicolas Boquet and Yann Le Bras

=head1 LICENSE

GNU GPL v3

=cut
