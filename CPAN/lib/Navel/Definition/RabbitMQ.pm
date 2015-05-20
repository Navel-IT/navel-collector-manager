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
            queues_suffix => [
                'word',
                ''
            ]
        }
    );

    return $validator->validate($parameters) && @{$parameters->{queues_suffix}};
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

sub get_queues_suffix {
    return shift->{__queues_suffix};
}

sub set_queues_suffix {
    return shift->set_generic('queues_suffix', shift);
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