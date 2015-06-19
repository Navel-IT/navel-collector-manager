# Copyright 2015 Navel-IT
# Navel Scheduler is developed by Yoann Le Garff, Nicolas Boquet and Yann Le Bras under GNU GPL v3

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

our $ORIGINAL_PROPERTIES = [qw/
    name
    host
    port
    user
    password
    timeout
    vhost
    exchange
    routing_key
    delivery_mode
    scheduling
/];

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
            delivery_mode => 'connector_props_delivery_mode',
            scheduling => 'connector_cron'
        }
    );

    $validator->type(
        connector_props_delivery_mode => sub {
            my $value = shift;

            return $value == 1 || $value == 2;
        },
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

sub merge {
   return shift->SUPER::merge(
        \&rabbitmq_definition_validator,
        shift
   );
}

sub set_name {
    return shift->merge(
        {
            name => shift
        }
    );
}

sub get_host {
    return shift->{__host};
}

sub set_host {
    return shift->merge(
        {
            host => shift
        }
    );
}

sub get_port {
    return shift->{__port};
}

sub set_port {
    return shift->merge(
        {
            port => shift
        }
    );
}

sub get_user {
    return shift->{__user};
}

sub set_user {
    return shift->merge(
        {
            user => shift
        }
    );
}

sub get_password {
    return shift->{__password};
}

sub set_password {
    return shift->merge(
        {
            password => shift
        }
    );
}

sub get_timeout {
    return shift->{__timeout};
}

sub set_timeout {
    return shift->merge(
        {
            timeout => shift
        }
    );
}

sub get_vhost {
    return shift->{__vhost};
}

sub set_vhost {
    return shift->merge(
        {
            vhost => shift
        }
    );
}

sub get_exchange {
    return shift->{__exchange};
}

sub set_exchange {
    return shift->merge(
        {
            exchange => shift
        }
    );
}

sub get_routing_key {
    return shift->{__routing_key};
}

sub set_routing_key {
    return shift->merge(
        {
            routing_key => shift
        }
    );
}

sub get_delivery_mode {
    return shift->{__delivery_mode};
}

sub set_delivery_mode {
    return shift->merge(
        {
            delivery_mode => shift
        }
    );
}

sub get_scheduling {
    return shift->{__scheduling};
}

sub set_scheduling {
    return shift->merge(
        {
            scheduling => shift
        }
    );
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
