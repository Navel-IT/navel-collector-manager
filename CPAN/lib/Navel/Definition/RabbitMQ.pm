# Copyright 2015 Navel-IT
# Navel Scheduler is developped by Yoann Le Garff, Nicolas Boquet and Yann Le Bras under GNU GPL v3

#-> BEGIN

#-> initialization

package Navel::Definition::RabbitMQ;

use strict;
use warnings;

use parent qw/
    Navel::Base::Definition
/;

use Exporter::Easy (
    OK => [qw/
        :all
        rabbitmq_definition_validator
    /],
    TAGS => [
        all => [qw/
            rabbitmq_definition_validator
        /]
    ]
);

use Data::Validate::Struct;

use DateTime::Event::Cron::Quartz;

use Navel::Utils qw/
    :all
/;

our $VERSION = 0.1;

#-> functions

sub rabbitmq_definition_validator($) {
    my $parameters = shift;

    my $validator = Data::Validate::Struct->new(
        {
            name => 'word',
            host => 'hostname',
            port => 'port',
            user => 'text',
            password => 'text',
            timeout => 'int',
            vhost => 'text',
            exchange => 'text',
            routing_key => 'text',
            scheduling => 'connector_cron'
        }
    );

    $validator->type(
        connector_cron => sub {
            return eval {
                DateTime::Event::Cron::Quartz->new(shift);
            };
        }
    );

    return $validator->validate($parameters);
}

#-> methods

sub new {
    return shift->SUPER::new(
        \&rabbitmq_definition_validator,
        shift
    );
}

sub set_generic {
   return shift->SUPER::set_generic(
        \&rabbitmq_definition_validator,
        shift,
        shift
   );
}

sub get_host {
    return shift->{__host};
}

sub set_host {
    return shift->set_generic('host', shift);
}

sub get_port {
    return shift->{__port};
}

sub set_port {
    return shift->set_generic('port', shift);
}

sub get_user {
    return shift->{__user};
}

sub set_user {
    return shift->set_generic('user', shift);
}

sub get_password {
    return shift->{__password};
}

sub set_password {
    return shift->set_generic('password', shift);
}

sub get_timeout {
    return shift->{__timeout};
}

sub set_timeout {
    return shift->set_generic('timeout', shift);
}

sub get_vhost {
    return shift->{__vhost};
}

sub set_vhost {
    return shift->set_generic('vhost', shift);
}

sub get_exchange {
    return shift->{__exchange};
}

sub set_exchange {
    return shift->set_generic('exchange', shift);
}

sub get_routing_key {
    return shift->{__routing_key};
}

sub set_routing_key {
    return shift->set_generic('routing_key', shift);
}

sub get_scheduling {
    return shift->{__scheduling};
}

sub set_scheduling {
    return shift->set_generic('scheduling', shift);
}

# sub AUTOLOAD {}

# sub DESTROY {}

1;

#-> END

__END__

=pod

=head1 NAME

Navel::Definition::RabbitMQ

=head1 AUTHOR

Yoann Le Garff, Nicolas Boquet and Yann Le Bras

=head1 LICENSE

GNU GPL v3

=cut
