# Copyright 2015 Navel-IT
# Navel Scheduler is developed by Yoann Le Garff, Nicolas Boquet and Yann Le Bras under GNU GPL v3

#-> BEGIN

#-> initialization

package Navel::Definition::RabbitMQ::Parser;

use strict;
use warnings;

use parent 'Navel::Base::Definition::Parser';

our $VERSION = 0.1;

#-> methods

sub new {
    shift->SUPER::new(
        'Navel::Definition::RabbitMQ',
        1,
        @_
    );
}

BEGIN {
    __PACKAGE__->create_getters(qw/
        host
        port
        user
        password
        vhost
        tls
        heartbeat
        exchange
        delivery_mode
        scheduling
    /);
}

# sub AUTOLOAD {}

# sub DESTROY {}

1;

#-> END

__END__

=pod

=head1 NAME

Navel::Definition::RabbitMQ::Parser

=head1 AUTHOR

Yoann Le Garff, Nicolas Boquet and Yann Le Bras

=head1 LICENSE

GNU GPL v3

=cut
