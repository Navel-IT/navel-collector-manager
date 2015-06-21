# Copyright 2015 Navel-IT
# Navel Scheduler is developed by Yoann Le Garff, Nicolas Boquet and Yann Le Bras under GNU GPL v3

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

sub new {
    shift->SUPER::new('Navel::Definition::RabbitMQ', 1);
}

sub get_hosts {
    shift->__get_all_by_getter('get_host');
}

sub get_ports {
    shift->__get_all_by_getter('get_port');
}

sub get_users {
    shift->__get_all_by_getter('get_user');
}

sub get_passwords {
    shift->__get_all_by_getter('get_password');
}

sub get_vhosts {
    shift->__get_all_by_getter('get_vhost');
}

sub get_exchanges {
    shift->__get_all_by_getter('get_exchanges');
}

sub get_routing_keys {
    shift->__get_all_by_getter('get_routing_key');
}

sub get_delivery_modes {
    shift->__get_all_by_getter('get_delivery_mode');
}

sub get_schedulings {
    shift->__get_all_by_getter('get_scheduling');
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
