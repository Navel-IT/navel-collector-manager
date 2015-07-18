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

our @ORIGINAL_PROPERTIES = qw/
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
    auto_connect
/;

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
            scheduling => 'connector_cron',
            auto_connect => 'connector_auto_connect'
        }
    );

    $validator->type(
        connector_props_delivery_mode => sub {
            my $value = shift;

            $value == 1 || $value == 2;
        },
        connector_cron => sub {
            eval {
                DateTime::Event::Cron::Quartz->new(shift);
            };
        },
        connector_auto_connect => sub {
            my $value = shift;

            $value == 0 || $value == 1;
        }
    );

    $validator->validate($parameters);
}

#-> methods

sub new {
    shift->SUPER::new(
        \&rabbitmq_definition_validator,
        shift
    );
}

sub merge {
   shift->SUPER::merge(
        \&rabbitmq_definition_validator,
        shift
   );
}

sub get_original_properties {
    shift->SUPER::get_original_properties(\@ORIGINAL_PROPERTIES);
}

sub set_name {
    shift->merge(
        {
            name => shift
        }
    );
}

sub get_host {
    shift->{__host};
}

sub set_host {
    shift->merge(
        {
            host => shift
        }
    );
}

sub get_port {
    shift->{__port};
}

sub set_port {
    shift->merge(
        {
            port => shift
        }
    );
}

sub get_user {
    shift->{__user};
}

sub set_user {
    shift->merge(
        {
            user => shift
        }
    );
}

sub get_password {
    shift->{__password};
}

sub set_password {
    shift->merge(
        {
            password => shift
        }
    );
}

sub get_timeout {
    shift->{__timeout};
}

sub set_timeout {
    shift->merge(
        {
            timeout => shift
        }
    );
}

sub get_vhost {
    shift->{__vhost};
}

sub set_vhost {
    shift->merge(
        {
            vhost => shift
        }
    );
}

sub get_exchange {
    shift->{__exchange};
}

sub set_exchange {
    shift->merge(
        {
            exchange => shift
        }
    );
}

sub get_routing_key {
    shift->{__routing_key};
}

sub set_routing_key {
    shift->merge(
        {
            routing_key => shift
        }
    );
}

sub get_delivery_mode {
    shift->{__delivery_mode};
}

sub set_delivery_mode {
    shift->merge(
        {
            delivery_mode => shift
        }
    );
}

sub get_scheduling {
    shift->{__scheduling};
}

sub set_scheduling {
    shift->merge(
        {
            scheduling => shift
        }
    );
}

sub get_auto_connect {
    shift->{__auto_connect};
}

sub set_auto_connect {
    shift->merge(
        {
            auto_connect => shift
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
