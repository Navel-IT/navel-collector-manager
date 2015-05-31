# Copyright 2015 Navel-IT
# Navel Scheduler is developped by Yoann Le Garff, Nicolas Boquet and Yann Le Bras under GNU GPL v3

#-> BEGIN

#-> initialization

package Navel::Definition::Connector::Etc::Parser;

use strict;
use warnings;

use parent qw/
    Navel::Base::Definition::Etc::Parser
/;

use Navel::Utils qw/
    :all
/;

our $VERSION = 0.1;

#-> methods

sub make {
    return shift->SUPER::make('Navel::Definition::Connector', 1, shift);
}

sub get_collections {
    return shift->__get_all_by_getter('get_collection');
}

sub get_types {
     return shift->__get_all_by_getter('get_type');
}

sub get_schedulings {
     return shift->__get_all_by_getter('get_scheduling');
}

sub get_exec_directory_paths {
    return shift->__get_all_by_getter('get_exec_directory_path');
}

sub get_exec_file_paths {
    return shift->__get_all_by_getter('get_exec_file_path');
}

# sub AUTOLOAD {}

# sub DESTROY {}

1;

#-> END

__END__

=pod

=head1 NAME

Navel::Definition::Connector::Etc::Parser

=head1 AUTHOR

Yoann Le Garff, Nicolas Boquet and Yann Le Bras

=head1 LICENSE

GNU GPL v3

=cut
