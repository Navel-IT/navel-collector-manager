# Copyright 2015 Navel-IT
# Navel Scheduler is developed by Yoann Le Garff, Nicolas Boquet and Yann Le Bras under GNU GPL v3

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

sub new {
    shift->SUPER::new('Navel::Definition::Connector', 1);
}

sub get_collections {
    shift->__get_all_by_getter('get_collection');
}

sub get_types {
    shift->__get_all_by_getter('get_type');
}

sub get_singletons {
    shift->__get_all_by_getter('get_singleton');
}

sub get_schedulings {
    shift->__get_all_by_getter('get_scheduling');
}

sub get_sources {
    shift->__get_all_by_getter('get_source');
}

sub get_inputs {
    shift->__get_all_by_getter('get_input');
}

sub get_exec_directory_paths {
    shift->__get_all_by_getter('get_exec_directory_path');
}

sub get_exec_file_paths {
    shift->__get_all_by_getter('get_exec_file_path');
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
