# Copyright 2015 Navel-IT
# Navel Scheduler is developped by Yoann Le Garff, Nicolas Boquet and Yann Le Bras under GNU GPL v3

#-> BEGIN

#-> initialization

package Navel::Scheduler::Cron;

use strict;
use warnings;

use parent qw/
    Navel::Base
/;

use Carp qw/
    carp
    croak
/;

use AnyEvent::DateTime::Cron;

use Net::AMQP::RabbitMQ;

use Navel::Scheduler::Cron::Exec;

use Navel::Utils qw/
    :all
/;

our $VERSION = 0.1;

#-> methods

sub new {
    my ($class, $connectors, $rabbitmq, $logger, $extra_parameters) = @_;

    if (blessed($connectors) eq 'Navel::Definition::Connector::Etc::Parser' && blessed($rabbitmq) eq 'Navel::Definition::RabbitMQ::Etc::Parser' && blessed($logger) eq 'Navel::Logger') {
        my $self = {
            __connectors => $connectors,
            __rabbitmq => $rabbitmq,
            __senders => [],
            __buffers => {},
            __logger => $logger,
            __cron => AnyEvent::DateTime::Cron->new(
                quartz => 1
            )
        };

        for my $connector (@{$self->{__connectors}->get_definitions()}) {
            $self->{__cron}->add($connector->get_scheduling(), # need to be blocking (per item name)
                sub {
                    my $body = Navel::Scheduler::Cron::Exec->new(
                        $connector,
                        $self->{__rabbitmq},
                        $self->{__logger},
                        $extra_parameters
                    )->exec()->serialize();

                    map { $self->__push_in_a_buffer($_, $body) } keys %{$self->get_buffers()};
                }
            );
        }

        $class = ref $class || $class;

        return bless $self, $class;
    }

    croak('Object(s) invalid(s).');
}

sub init_senders {
    my $self = shift;

    for my $rabbitmq (@{$self->get_rabbitmq()->get_definitions()}) {
        $self->get_logger()->push_to_buffer('Initialize sender ' . $rabbitmq->get_name())->flush_buffer(1);

        $self->__init_a_buffer($rabbitmq->get_name());

        my $sender = Net::AMQP::RabbitMQ->new();

        push @{$self->get_senders()}, {
            __net => $sender,
            __definition => $rabbitmq
        };
    }

    return $self;
}

sub connect_senders {
    my $self = shift;

    for my $sender (@{$self->get_senders()}) {
        my %options = (
            user => $sender->{__definition}->get_user(),
            password => $sender->{__definition}->get_password(),
            port => $sender->{__definition}->get_port(),
            vhost => $sender->{__definition}->get_vhost()
        );

        $options{timeout} = $sender->{__definition}->get_timeout() if ($sender->{__definition}->get_timeout());

        unless ($sender->{__net}->is_connected()) {
            eval {
                $sender->{__net}->connect($sender->{__definition}->get_host(), \%options);
            };

            $self->get_logger()->push_to_buffer('Connect sender ' . $sender->{__definition}->get_name() . ' : ' . ($@ ? $@ : 'successful'))->flush_buffer(1);
        } else {
            $self->get_logger()->push_to_buffer('Connect sender ' . $sender->{__definition}->get_name() . ' : seem already connected')->flush_buffer(1);
        }
    }

    return $self;
}

sub register_senders {
    my $self = shift;

    my $channel_id = 1;

    for my $sender (@{$self->get_senders()}) {
        $self->get_cron()->add($sender->{__definition}->get_scheduling(), # need to be blocking (per item name)
            sub {
                if ($sender->{__net}->is_connected()) {
                    my @buffer = @{$self->get_a_buffer($sender->{__definition}->get_name())};

                    if (@buffer) {
                        $self->__clear_a_buffer($sender->{__definition}->get_name());

                        eval {
                            $sender->{__net}->channel_open($channel_id);

                            for my $body (@buffer) {
                                $self->get_logger()->push_to_buffer('Publishing for sender ' . $sender->{__definition}->get_name() . ' on channel ' . $channel_id)->flush_buffer(1);

                                $sender->{__net}->publish($channel_id, $sender->{__definition}->get_routing_key(), $body,
                                    {
                                        exchange => $sender->{__definition}->get_exchange()
                                    }
                                );
                            }

                            $sender->{__net}->channel_close($channel_id);
                        };

                        $self->get_logger()->push_to_buffer('Publish datas for sender ' . $sender->{__definition}->get_name() . ' : ' . ($@ ? $@ : 'successful'))->flush_buffer(1);
                    } else {
                        $self->get_logger()->push_to_buffer('Buffer for sender ' . $sender->{__definition}->get_name() . ' is empty')->flush_buffer(1);
                    }
                } else {
                    $self->get_logger()->push_to_buffer('Publish datas for sender ' . $sender->{__definition}->get_name() . " : isn't connected")->flush_buffer(1);
                }
            }
        );
    }

    return $self;
}

sub disconnect_senders {
    my $self = shift;

    $_->{__net}->disconnect() for (@{$self->get_senders()});

    return $self;

}

sub start {
    my $self = shift;

    $self->get_cron()->start()->recv();

    return $self;
}

sub stop {
    my $self = shift;

    $self->get_cron()->stop();

    return $self;
}

sub get_connectors {
    return shift->{__connectors};
}

sub get_rabbitmq {
    return shift->{__rabbitmq};
}

sub get_senders {
    return shift->{__senders};
}

sub get_buffers {
    return shift->{__buffers};
}

sub get_a_buffer {
    my ($self, $buffer_name) = @_;

    return $self->get_buffers()->{$buffer_name};
}

sub __init_a_buffer {
    my ($self, $buffer_name) = @_;

    $self->get_buffers()->{$buffer_name} = [];

    return $self;
}

sub __push_in_a_buffer {
    my ($self, $buffer_name, $body) = @_;

    push @{$self->get_buffers()->{$buffer_name}}, $body;

    return $self;
}

sub __clear_a_buffer {
    my ($self, $buffer_name) = @_;

    undef @{$self->get_buffers()->{$buffer_name}};

    return $self;
}

sub get_logger {
    return shift->{__logger};
}

sub get_cron {
    return shift->{__cron};
}

# sub AUTOLOAD {}

sub DESTROY {
    shift->disconnect_senders();
}

1;

#-> END

__END__

=pod

=head1 NAME

Navel::Scheduler::Cron

=head1 AUTHOR

Yoann Le Garff, Nicolas Boquet and Yann Le Bras

=head1 LICENSE

GNU GPL v3

=cut