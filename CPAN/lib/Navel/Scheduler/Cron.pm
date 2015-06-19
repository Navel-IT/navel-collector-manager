# Copyright 2015 Navel-IT
# Navel Scheduler is developed by Yoann Le Garff, Nicolas Boquet and Yann Le Bras under GNU GPL v3

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

use AnyEvent::AIO;

use IO::AIO;

use Navel::Scheduler::Cron::Fork;

use Navel::RabbitMQ::Publisher;

use Navel::RabbitMQ::Serialize::Data qw/
    to
/;

use Navel::Utils qw/
    :all
/;

our $VERSION = 0.1;

#-> functions

my $__serialize_log_and_push_in_queues = sub {
    my ($logger, $connector, $publishers, $datas) = @_;

    my $generic_message = 'Get and serialize datas for connector ' . $connector->get_name();

    my $serialized = eval {
        to(
            $connector,
            $datas
        );
    };

    unless ($@) {
        $logger->good($generic_message . '.', 'info');

        map { $_->push_in_queue($serialized) } @{$publishers};
    } else {
        $logger->bad($generic_message . ' failed : ' . $@ . ' .', 'err');
    }
};

#-> methods

sub new {
    my ($class, $connectors, $rabbitmq, $logger) = @_;

    if (blessed($connectors) eq 'Navel::Definition::Connector::Etc::Parser' && blessed($rabbitmq) eq 'Navel::Definition::RabbitMQ::Etc::Parser' && blessed($logger) eq 'Navel::Logger') {
        my $self = {
            __connectors => $connectors,
            __rabbitmq => $rabbitmq,
            __publishers => [],
            __queues => {},
            __logger => $logger,
            __cron => AnyEvent::DateTime::Cron->new(
                quartz => 1
            ),
            __locks => {}
        };

        $class = ref $class || $class;

        return bless $self, $class;
    }

    croak('one or more objects are invalids.');
}

sub register_logger {
    my $self = shift;

    $self->get_cron()->add(
        '* * * * * ?',
        name => 'logger',
        single => 1,
        sub {
            $self->get_logger()->flush_queue(1);
        }
    );

    return $self;
}

sub register_connector {
    my $self = shift;

    my $connector = $self->get_connectors()->get_by_name(shift);

    if (defined $connector) {
        return $self->get_cron()->add(
            $connector->get_scheduling(),
            name => 'connector_' . $connector->get_name(),
            sub {
                local ($@, $!);

                unless ($self->get_locks()->{$connector->get_name()}) {
                    $self->get_locks()->{$connector->get_name()} = $connector->get_singleton();

                    aio_open($connector->get_exec_file_path(), IO::AIO::O_RDONLY, 0,
                        sub {
                            my $fh = shift;

                            if ($fh) {
                                my $connector_content = '';

                                $self->get_logger()->good('Connector ' . $connector->get_name() . ' : successfuly opened file ' . $connector->get_exec_file_path() . '.', 'debug');

                                aio_read($fh, 0, -s $fh, $connector_content, 0,
                                    sub {
                                        close $fh or $self->get_logger()->bad('Connector ' . $connector->get_name() . ' : ' . $! . '.', 'err');

                                        if ($connector->is_type_code()) {
                                            Navel::Scheduler::Cron::Fork->new(
                                                $connector,
                                                $self->get_logger(),
                                                $connector_content
                                            )->when_done(
                                                sub {
                                                    $__serialize_log_and_push_in_queues->(
                                                        $self->get_logger(),
                                                        $connector,
                                                        $self->get_publishers(),
                                                        shift
                                                    );

                                                    $self->get_locks()->{$connector->get_name()} = 0;
                                                }
                                            );
                                        } else {
                                            $__serialize_log_and_push_in_queues->(
                                                $self->get_logger(),
                                                $connector,
                                                $self->get_publishers(),
                                                $connector_content
                                            );

                                            $self->get_locks()->{$connector->get_name()} = 0;
                                        }
                                    }
                                )
                            } else {
                                $self->get_logger()->bad('Connector ' . $connector->get_name() . ' : ' . $! . '.', 'err');

                                $self->get_locks()->{$connector->get_name()} = 0;
                            }
                        }
                    );
                } else {
                    $self->get_logger()->push_to_queue('Connector ' . $connector->get_name() . ' already running.', 'info');
                }
            }
        );
    }

    return 0;
}

sub register_connectors {
    my $self = shift;

    $self->register_connector($_->get_name()) for (@{$self->get_connectors()->get_definitions()});

    return $self;
}

sub init_publishers {
    my $self = shift;

    for my $rabbitmq (@{$self->get_rabbitmq()->get_definitions()}) {
        $self->get_logger()->push_to_queue('Initialize publisher ' . $rabbitmq->get_name() . '.', 'info')->flush_queue(1);

        push @{$self->get_publishers()}, Navel::RabbitMQ::Publisher->new($rabbitmq);
    }

    return $self;
}

sub connect_publishers {
    my $self = shift;

    for my $publisher (@{$self->get_publishers()}) {
        my $publisher_generic_message = 'Connect publisher ' . $publisher->get_definition()->get_name();

        unless ($publisher->get_net()->is_connected()) {
            my $connect_message = $publisher->connect();

            if ($connect_message) {
                $self->get_logger()->bad($publisher_generic_message . ' : ' . $connect_message . '.', 'warn')->flush_queue(1);
            } else {
                $self->get_logger()->good($publisher_generic_message . '.', 'notice')->flush_queue(1);
            }
        } else {
            $self->get_logger()->bad($publisher_generic_message . ' : seem already connected.', 'notice')->flush_queue(1);
        }
    }

    return $self;
}

sub register_publishers {
    my $self = shift;

    local $@;

    for my $publisher (@{$self->get_publishers()}) {
        $self->get_cron()->add(
            $publisher->get_definition()->get_scheduling(),
            name => 'publisher_' . $publisher->get_definition()->get_name(),
            single => 1,
            sub {
                my $publish_generic_message = 'Publish datas for publisher ' . $publisher->get_definition()->get_name() . ' on channel ' . $Navel::RabbitMQ::Publisher::CHANNEL_ID;

                if ($publisher->get_net()->is_connected()) {
                    my @queue = @{$publisher->get_queue()};

                    if (@queue) {
                        $self->get_logger()->push_to_queue('Clear queue for publisher ' . $publisher->get_definition()->get_name() . '.', 'notice');

                        $publisher->clear_queue();

                        eval {
                            for my $body (@queue) {
                                $self->get_logger()->push_to_queue($publish_generic_message . ' : sending one body.', 'debug');

                                $publisher->get_net()->publish(
                                    $Navel::RabbitMQ::Publisher::CHANNEL_ID,
                                    $publisher->get_definition()->get_routing_key(),
                                    $body,
                                    {
                                        exchange => $publisher->get_definition()->get_exchange()
                                    },
                                    {
                                        delivery_mode => $publisher->get_definition()->get_delivery_mode()
                                    }
                                );
                            }
                        };

                        if ($@) {
                            $self->get_logger()->bad($publish_generic_message . ' : ' . $@ . '.', 'warn');
                        } else {
                            $self->get_logger()->good($publish_generic_message . '.', 'notice');
                        }
                    } else {
                        $self->get_logger()->bad('Buffer for publisher ' . $publisher->get_definition()->get_name() . ' is empty.', 'info');
                    }
                } else {
                    $self->get_logger()->bad($publish_generic_message . ' : publisher is not connected.', 'warn');
                }
            }
        );
    }

    return $self;
}

sub disconnect_publishers {
    my $self = shift;

    for (@{$self->get_publishers()}) {
        my $disconnect_generic_message = 'Disconnect publisher ' . $_->get_definition()->get_name();

        if (my $error = $_->disconnect()) {
            $self->get_logger()->good($disconnect_generic_message . ' : ' . $error . '.', 'notice');
        } else {
            $self->get_logger()->good($disconnect_generic_message . '.', 'notice');
        }
    }

    return $self;
}

sub unregister_job_by_name {
    my ($self, $job_name) = @_;

    my $jobs = $self->get_cron()->jobs();

    for my $job_id (keys %{$jobs}) {
        return $self->get_cron()->delete($job_id) if ($jobs->{$job_id}->{name} eq $job_name);
    }

    return 0;
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

sub get_publisher_by_definition_name {
    my ($self, $definition_name) = @_;

    for (@{$self->get_publishers()}) {
        return $_ if ($_->get_definition()->get_name() eq $definition_name);
    }

    return undef;
}

sub get_queues {
    return shift->{__queues};
}

sub get_logger {
    return shift->{__logger};
}

sub get_cron {
    return shift->{__cron};
}

sub get_locks {
    return shift->{__locks};
}

# sub AUTOLOAD {}

# sub DESTROY {}

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
