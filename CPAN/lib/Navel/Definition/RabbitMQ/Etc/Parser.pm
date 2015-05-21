# Copyright 2015 Navel-IT
# Navel Scheduler is developped by Yoann Le Garff, Nicolas Boquet and Yann Le Bras under GNU GPL v3

#-> BEGIN

#-> initialization

package Navel::Definition::RabbitMQ::Etc::Parser;

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
    return shift->SUPER::make('Navel::Definition::RabbitMQ', 0, shift);
}

sub get_hosts {
    return shift->__get_all_by_getter('get_host');
}

sub get_ports {
    return shift->__get_all_by_getter('get_port');
}

sub get_users {
    return shift->__get_all_by_getter('get_user');
}

sub get_passwords {
    return shift->__get_all_by_getter('get_password');
}

sub get_vhosts {
    return shift->__get_all_by_getter('get_vhost');
}

sub get_queues_suffix {
    return shift->__get_all_by_getter('get_queues_suffix');
}

# sub AUTOLOAD {}

# sub DESTROY {}

1;

#-> END

__END__

=pod

=head1 NAME

Navel::Definition::RabbitMQ::Etc::Parser

=head1 AUTHOR

Yoann Le Garff, Nicolas Boquet and Yann Le Bras

=head1 LICENSE

GNU GPL v3

=cut