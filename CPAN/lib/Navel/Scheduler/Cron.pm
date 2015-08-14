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

use Scalar::Util::Numeric qw/
    isint
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

#-> methods

sub new {
    my ($class, $connectors, $rabbitmq, $logger, $maximum_simultaneous_exec) = @_;

    croak('one or more objects are invalids.') unless (blessed($connectors) eq 'Navel::Definition::Connector::Etc::Parser' && blessed($rabbitmq) eq 'Navel::Definition::RabbitMQ::Etc::Parser' && blessed($logger) eq 'Navel::Logger' && isint($maximum_simultaneous_exec) && $maximum_simultaneous_exec >= 0);

    my $self = {
        __connectors => $connectors,
        __rabbitmq => $rabbitmq,
        __publishers => [],
        __queues => {},
        __logger => $logger,
        __cron => AnyEvent::DateTime::Cron->new(
            quartz => 1
        ),
        __locks => {},
        __maximum_simultaneous_exec => $maximum_simultaneous_exec,
        __connectors_running => 0
    };

    bless $self, ref $class || $class;
}

sub register_logger {
    my $self = shift;

    my $job_name = 'logger_0';

    $self->get_cron()->add(
        '*/2 * * * * ?',
        name => $job_name,
        single => 1,
        sub {
            $self->get_logger()->flush_queue(1);
        }
    );

    $self;
}

sub register_connector {
    my $self = shift;

    my $connector = $self->get_connectors()->get_by_name(shift);

    croak('undefined definition') unless (defined $connector);

    my $job_name = 'connector_' . $connector->get_name();

    $self->get_cron()->add(
        $connector->get_scheduling(),
        name => $job_name,
        single => 1,
        sub {
            local ($@, $!);

            if ( ! $self->get_maximum_simultaneous_exec() || $self->get_maximum_simultaneous_exec() > $self->get_connectors_running()) {
                unless ($self->get_locks()->{$job_name}) {
                    $self->a_connector_start();

                    $self->get_locks()->{$job_name} = $connector->get_singleton();

                    aio_open($connector->get_exec_file_path(), IO::AIO::O_RDONLY, 0,
                        sub {
                            my $fh = shift;

                            if ($fh) {
                                my $connector_content = '';

                                $self->get_logger()->good('Connector ' . $connector->get_name() . ' : successfuly opened file ' . $connector->get_exec_file_path() . '.', 'debug');

                                aio_read($fh, 0, -s $fh, $connector_content, 0,
                                    sub {
                                        close $fh or $self->get_logger()->bad('Connector ' . $connector->get_name() . ' : ' . $! . '.', 'err');

                                        my $get_and_push_generic_message = 'Get and push in queue an event for connector ' . $connector->get_name() . '.';

                                        if ($connector->is_type_code()) {
                                            Navel::Scheduler::Cron::Fork->new(
                                                $connector,
                                                $connector_content,
                                                $self->get_publishers(),
                                                $self->get_logger()
                                            )->when_done(
                                                sub {
                                                    my $datas = shift;

                                                    $self->get_logger()->push_in_queue($get_and_push_generic_message, 'info');

                                                    $_->push_in_queue(
                                                        {
                                                            connector => $connector,
                                                            datas => $datas
                                                        }
                                                    ) for (@{$self->get_publishers()});

                                                    $self->get_locks()->{$job_name} = 0;

                                                    $self->a_connector_stop();
                                                }
                                            );
                                        } else {
                                            $self->get_logger()->push_in_queue($get_and_push_generic_message, 'info');

                                            $_->push_in_queue(
                                                {
                                                    connector => $connector,
                                                    datas => $connector_content
                                                }
                                            ) for (@{$self->get_publishers()});

                                            $self->get_locks()->{$job_name} = 0;

                                            $self->a_connector_stop();
                                        }
                                    }
                                )
                            } else {
                                $self->get_logger()->bad('Connector ' . $connector->get_name() . ' : ' . $! . '.', 'err');

                                $_->push_in_queue(
                                    {
                                        connector => $connector
                                    },
                                    'set_ko_no_source'
                                ) for (@{$self->get_publishers()});

                                $self->get_locks()->{$job_name} = 0;

                                $self->a_connector_stop();
                            }
                        }
                    );
                } else {
                    $self->get_logger()->push_in_queue('Connector ' . $connector->get_name() . ' is already running.', 'info');
                }
            } else {
                 $self->get_logger()->push_in_queue('Too much connectors are running (maximum of ' . $self->get_maximum_simultaneous_exec() . ').', 'info');
            }
        }
    );

    $self;
}

sub register_connectors {
    my $self = shift;

    $self->register_connector($_->get_name()) for (@{$self->get_connectors()->get_definitions()});

    $self;
}

sub init_publisher {
    my $self = shift;

    my $rabbitmq = $self->get_rabbitmq()->get_by_name(shift);

    croak('undefined definition') unless (defined $rabbitmq);

    $self->get_logger()->push_in_queue('Initialize publisher ' . $rabbitmq->get_name() . '.', 'info');

    push @{$self->get_publishers()}, Navel::RabbitMQ::Publisher->new($rabbitmq);

    $self;
}

sub init_publishers {
    my $self = shift;

    $self->init_publisher($_->get_name()) for (@{$self->get_rabbitmq()->get_definitions()});

    $self;
}

sub connect_publisher {
    my $self = shift;

    my $publisher = $self->get_publisher_by_definition_name(shift);

    croak('undefined definition') unless (defined $publisher);

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

    $self;
}

sub connect_publishers {
    my $self = shift;

    $self->connect_publisher($_->get_definition()->get_name()) for (@{$self->get_publishers()});

    $self;
}

sub register_publisher {
    my $self = shift;

    my $publisher = $self->get_publisher_by_definition_name(shift);

    croak('undefined definition') unless (defined $publisher);

    $self->get_cron()->add(
        $publisher->get_definition()->get_scheduling(),
        name => 'publisher_' . $publisher->get_definition()->get_name(),
        single => 1,
        sub {
            local $@;

            my $publish_generic_message = 'Publish events for publisher ' . $publisher->get_definition()->get_name() . ' on channel ' . $Navel::RabbitMQ::Publisher::CHANNEL_ID;

            if (my @queue = @{$publisher->get_queue()}) {
                if ($publisher->get_net()->is_connected()) {
                    $self->get_logger()->push_in_queue('Clear queue for publisher ' . $publisher->get_definition()->get_name() . '.', 'notice');

                    $publisher->clear_queue();

                    eval {
                        for my $event (@queue) {
                            my $serialize_generic_message = 'Serialize datas for collection ' . $event->get_collection() . '.';

                            my $serialized = eval {
                                $event->get_datas_serialized();
                            };

                            unless ($@) {
                                $self->get_logger()->good($serialize_generic_message, 'debug');

                                my $routing_key = $event->get_routing_key();

                                $self->get_logger()->push_in_queue($publish_generic_message . ' : sending one event with routing key ' . $routing_key . '.', 'debug');

                                $publisher->get_net()->publish(
                                    $Navel::RabbitMQ::Publisher::CHANNEL_ID,
                                    $routing_key,
                                    $serialized,
                                    {
                                        exchange => $publisher->get_definition()->get_exchange()
                                    },
                                    {
                                        delivery_mode => $publisher->get_definition()->get_delivery_mode()
                                    }
                                );
                            } else {
                                $self->get_logger()->bad($serialize_generic_message, 'debug');
                            }
                        }
                    };

                    if ($@) {
                        $self->get_logger()->bad($publish_generic_message . ' : ' . $@ . '.', 'warn');
                    } else {
                        $self->get_logger()->good($publish_generic_message . '.', 'notice');
                    }
                } else {
                    $self->get_logger()->bad($publish_generic_message . ' : publisher is not connected.', 'warn');
                }
            } else {
                $self->get_logger()->bad('Buffer for publisher ' . $publisher->get_definition()->get_name() . ' is empty.', 'info');
            }
        }
    );

    $self;
}

sub register_publishers {
    my $self = shift;

    $self->register_publisher($_->get_definition()->get_name()) for (@{$self->get_publishers()});

    $self;
}

sub disconnect_publisher {
    my $self = shift;

    my $publisher = $self->get_publisher_by_definition_name(shift);

    croak('undefined definition') unless (defined $publisher);

    my $disconnect_generic_message = 'Disconnect publisher ' . $publisher->get_definition()->get_name();

    if (my $error = $publisher->disconnect()) {
        $self->get_logger()->good($disconnect_generic_message . ' : ' . $error . '.', 'notice');
    } else {
        $self->get_logger()->good($disconnect_generic_message . '.', 'notice');
    }

    $self;
}

sub disconnect_publishers {
    my $self = shift;

    $self->disconnect_publisher($_->get_name()) for (@{$self->get_publishers()});

    $self;
}

sub unregister_job_by_name {
    my ($self, $job_name) = @_;

    my $jobs = $self->get_cron()->jobs();

    for my $job_id (keys %{$jobs}) {
        return $self->get_cron()->delete($job_id) if ($jobs->{$job_id}->{name} eq $job_name);
    }
}

sub start {
    my $self = shift;

    $self->get_cron()->start()->recv();

    $self;
}

sub stop {
    my $self = shift;

    $self->get_cron()->stop();

    $self;
}

sub get_connectors {
    shift->{__connectors};
}

sub get_rabbitmq {
    shift->{__rabbitmq};
}

sub get_publishers {
    shift->{__publishers};
}

sub get_publisher_by_definition_name {
    my ($self, $definition_name) = @_;

    for (@{$self->get_publishers()}) {
        return $_ if ($_->get_definition()->get_name() eq $definition_name);
    }

    undef;
}

sub delete_publisher_by_definition_name {
    my ($self, $definition_name) = @_;

    my $publishers = $self->get_publishers();

    my $definition_to_delete_index = 0;

    my $finded;

    $definition_to_delete_index++ until ($finded = $publishers->[$definition_to_delete_index]->get_definition()->get_name() eq $definition_name);

    if ($finded) {
        splice @{$publishers}, $definition_to_delete_index, 1;
    } else {
        croak($self->get_definition_package() . ' : definition ' . $definition_name . ' does not exists');
    }

    undef;
}

sub get_queues {
    shift->{__queues};
}

sub get_logger {
    shift->{__logger};
}

sub get_cron {
    shift->{__cron};
}

sub get_locks {
    shift->{__locks};
}

sub get_maximum_simultaneous_exec {
    shift->{__maximum_simultaneous_exec};
}

sub get_connectors_running {
    shift->{__connectors_running};
}

sub a_connector_start {
    shift->{__connectors_running}++;
}

sub a_connector_stop {
    shift->{__connectors_running}--;
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
