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
            __publishers => [],
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

sub init_publishers {
    my $self = shift;

    for my $rabbitmq (@{$self->get_rabbitmq()->get_definitions()}) {
        $self->get_logger()->push_to_buffer('Initialize publisher ' . $rabbitmq->get_name() . '.', 'info')->flush_buffer(1);

        $self->__init_a_buffer($rabbitmq->get_name());

        my $publisher = Net::AMQP::RabbitMQ->new();

        push @{$self->get_publishers()}, {
            __net => $publisher,
            __definition => $rabbitmq
        };
    }

    return $self;
}

sub connect_publishers {
    my $self = shift;

    for my $publisher (@{$self->get_publishers()}) {
        my %options = (
            user => $publisher->{__definition}->get_user(),
            password => $publisher->{__definition}->get_password(),
            port => $publisher->{__definition}->get_port(),
            vhost => $publisher->{__definition}->get_vhost()
        );

        $options{timeout} = $publisher->{__definition}->get_timeout() if ($publisher->{__definition}->get_timeout());

        my $publisher_generic_message = 'Connect publisher ' . $publisher->{__definition}->get_name();

        unless ($publisher->{__net}->is_connected()) {
            eval {
                $publisher->{__net}->connect($publisher->{__definition}->get_host(), \%options);
            };

            if ($@) {
                $self->get_logger()->bad($publisher_generic_message . ' : ' . $@ . '.', 'warn')->flush_buffer(1);
            } else {
                $self->get_logger()->good($publisher_generic_message . '.', 'notice')->flush_buffer(1);
            }
        } else {
            $self->get_logger()->bad($publisher_generic_message . ' : seem already connected.', 'notice')->flush_buffer(1);
        }
    }

    return $self;
}

sub register_publishers {
    my $self = shift;

    my $channel_id = 1;

    for my $publisher (@{$self->get_publishers()}) {
        $self->get_cron()->add($publisher->{__definition}->get_scheduling(), # need to be blocking (per item name)
            sub {
                my $publish_generic_message = 'Publish datas for publisher ' . $publisher->{__definition}->get_name() . ' on channel ' . $channel_id;

                if ($publisher->{__net}->is_connected()) {
                    my @buffer = @{$self->get_a_buffer($publisher->{__definition}->get_name())};

                    if (@buffer) {
                        $self->__clear_a_buffer($publisher->{__definition}->get_name());

                        eval {
                            $publisher->{__net}->channel_open($channel_id);

                            for my $body (@buffer) {
                                $self->get_logger()->push_to_buffer($publish_generic_message . ' : send body.', 'info')->flush_buffer(1);

                                $publisher->{__net}->publish($channel_id, $publisher->{__definition}->get_routing_key(), $body,
                                    {
                                        exchange => $publisher->{__definition}->get_exchange()
                                    }
                                );
                            }

                            $publisher->{__net}->channel_close($channel_id);
                        };

                        if ($@) {
                            $self->get_logger()->bad($publish_generic_message . ' : ' . $@ . '.', 'warn')->flush_buffer(1);
                        } else {
                            $self->get_logger()->good($publish_generic_message . '.', 'notice')->flush_buffer(1);
                        }
                    } else {
                        $self->get_logger()->bad('Buffer for publisher ' . $publisher->{__definition}->get_name() . ' is empty.', 'info')->flush_buffer(1);
                    }
                } else {
                    $self->get_logger()->bad($publish_generic_message . ' : publisher is not connected.', 'warn')->flush_buffer(1);
                }
            }
        );
    }

    return $self;
}

sub disconnect_publishers {
    my $self = shift;

    $_->{__net}->disconnect() for (@{$self->get_publishers()});

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

sub get_publishers {
    return shift->{__publishers};
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
    shift->disconnect_publishers();
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
