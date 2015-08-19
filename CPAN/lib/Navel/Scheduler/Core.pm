# Copyright 2015 Navel-IT
# Navel Scheduler is developed by Yoann Le Garff, Nicolas Boquet and Yann Le Bras under GNU GPL v3

#-> BEGIN

#-> initialization

package Navel::Scheduler::Core;

use strict;
use warnings;

use parent 'Navel::Base';

use Carp 'croak';

use Scalar::Util::Numeric 'isint';

use AnyEvent::DateTime::Cron;
use AnyEvent::AIO;

use IO::AIO;

use Navel::Scheduler::Core::Fork;
use Navel::RabbitMQ::Publisher;
use Navel::RabbitMQ::Serialize::Data 'to';
use Navel::Utils 'blessed';

our $VERSION = 0.1;

#-> methods

sub new {
    my ($class, $connectors, $rabbitmq, $logger, $maximum_simultaneous_exec) = @_;

    croak('one or more objects are invalids.') unless (blessed($connectors) eq 'Navel::Definition::Connector::Parser' && blessed($rabbitmq) eq 'Navel::Definition::RabbitMQ::Parser' && blessed($logger) eq 'Navel::Logger' && isint($maximum_simultaneous_exec) && $maximum_simultaneous_exec >= 0);

    my $self = {
        connectors => $connectors,
        rabbitmq => $rabbitmq,
        publishers => [],
        logger => $logger,
        cron => AnyEvent::DateTime::Cron->new(
            quartz => 1
        ),
        locks => {},
        maximum_simultaneous_exec => $maximum_simultaneous_exec,
        connectors_running => 0
    };

    bless $self, ref $class || $class;
}

sub register_logger {
    my $self = shift;

    my $job_name = 'logger_0';

    $self->{cron}->add(
        '*/2 * * * * ?',
        name => $job_name,
        single => 1,
        sub {
            $self->{logger}->flush_queue(1);
        }
    );

    $self;
}

sub register_connector {
    my $self = shift;

    my $connector = $self->{connectors}->definition_by_name(shift);

    croak('undefined definition') unless (defined $connector);

    my $job_name = 'connector_' . $connector->{name};

    $self->{cron}->add(
        $connector->{scheduling},
        name => $job_name,
        single => 1,
        sub {
            local ($@, $!);

            if ( ! $self->{maximum_simultaneous_exec} || $self->{maximum_simultaneous_exec} > $self->{connectors_running}) {
                unless ($self->{locks}->{$job_name}) {
                    $self->{connectors_running}++;

                    $self->{locks}->{$job_name} = $connector->{singleton};

                    aio_open($connector->exec_file_path(), IO::AIO::O_RDONLY, 0,
                        sub {
                            my $fh = shift;

                            my $get_and_push_generic_message = 'Add an event from connector ' . $connector->{name} . ' in the queue of existing publishers.';

                            if ($fh) {
                                my $connector_content = '';

                                $self->{logger}->good('Connector ' . $connector->{name} . ' : successfuly opened file ' . $connector->exec_file_path() . '.', 'debug');

                                aio_read($fh, 0, -s $fh, $connector_content, 0,
                                    sub {
                                        close $fh or $self->{logger}->bad('Connector ' . $connector->{name} . ' : ' . $! . '.', 'err');

                                        if ($connector->is_type_code()) {
                                            Navel::Scheduler::Core::Fork->new(
                                                $connector,
                                                $connector_content,
                                                $self->{publishers},
                                                $self->{logger}
                                            )->when_done(
                                                sub {
                                                    my $datas = shift;

                                                    $self->{logger}->push_in_queue($get_and_push_generic_message, 'info');

                                                    $_->push_in_queue(
                                                        {
                                                            connector => $connector,
                                                            datas => $datas
                                                        }
                                                    ) for (@{$self->{publishers}});

                                                    $self->{locks}->{$job_name} = 0;

                                                    $self->{connectors_running}--;
                                                }
                                            );
                                        } else {
                                            $self->{logger}->push_in_queue($get_and_push_generic_message, 'info');

                                            $_->push_in_queue(
                                                {
                                                    connector => $connector,
                                                    datas => $connector_content
                                                }
                                            ) for (@{$self->{publishers}});

                                            $self->{locks}->{$job_name} = 0;

                                            $self->{connectors_running}--;
                                        }
                                    }
                                );
                            } else {
                                $self->{logger}->bad('Connector ' . $connector->{name} . ' : ' . $! . '.', 'err');

                                $self->{logger}->push_in_queue($get_and_push_generic_message, 'info');

                                $_->push_in_queue(
                                    {
                                        connector => $connector
                                    },
                                    'set_ko_no_source'
                                ) for (@{$self->{publishers}});

                                $self->{locks}->{$job_name} = 0;

                                $self->{connectors_running}--;
                            }
                        }
                    );
                } else {
                    $self->{logger}->push_in_queue('Connector ' . $connector->{name} . ' is already running.', 'info');
                }
            } else {
                $self->{logger}->push_in_queue('Too much connectors are running (maximum of ' . $self->{maximum_simultaneous_exec} . ').', 'info');
            }
        }
    );

    $self;
}

sub register_connectors {
    my $self = shift;

    $self->register_connector($_->{name}) for (@{$self->{connectors}->{definitions}});

    $self;
}

sub init_publisher {
    my $self = shift;

    my $rabbitmq = $self->{rabbitmq}->definition_by_name(shift);

    croak('undefined definition') unless (defined $rabbitmq);

    $self->{logger}->push_in_queue('Initialize publisher ' . $rabbitmq->{name} . '.', 'notice');

    push @{$self->{publishers}}, Navel::RabbitMQ::Publisher->new($rabbitmq);

    $self;
}

sub init_publishers {
    my $self = shift;

    $self->init_publisher($_->{name}) for (@{$self->{rabbitmq}->{definitions}});

    $self;
}

sub connect_publisher {
    my $self = shift;

    my $publisher = $self->publisher_by_definition_name(shift);

    croak('undefined definition') unless (defined $publisher);

    my $publisher_connect_generic_message = 'Connect publisher ' . $publisher->{definition}->{name};

    unless ($publisher->is_connected()) {
        my $publisher_generic_message = 'Publisher ' . $publisher->{definition}->{name};

        eval {
            $publisher->connect(
                {
                    on_success => sub {
                        my $amqp_connection = shift;

                        $self->{logger}->good($publisher_connect_generic_message . ' successfuly connected.', 'notice');

                        $amqp_connection->open_channel(
                            on_success => sub {
                                $self->{logger}->good($publisher_generic_message . ' : channel opened.', 'notice');
                            },
                            on_failure => sub {
                                $self->{logger}->bad($publisher_generic_message . ' : channel failure ... ' . join(' ', @_) . '.', 'notice');
                            },
                            on_close => sub {
                                $self->{logger}->push_in_queue($publisher_generic_message . ' : channel closed.', 'notice');

                                $publisher->disconnect();
                            }
                        );
                    },
                    on_failure => sub {
                        $self->{logger}->bad($publisher_connect_generic_message . ' : failure ... ' . join(' ', @_) . '.', 'warn');
                    },
                    on_read_failure => sub {
                        $self->{logger}->bad($publisher_generic_message . ' : read failure ... ' . join(' ', @_) . '.', 'warn');
                    },
                    on_return => sub {
                        $self->{logger}->bad($publisher_generic_message . ' : unable to deliver frame.', 'warn');
                    },
                    on_close => sub {
                        $self->{logger}->push_in_queue($publisher_generic_message . ' disconnected.', 'notice');
                    }
                }
            );
        };

        unless ($@) {
            $self->{logger}->push_in_queue($publisher_connect_generic_message . ' ...', 'notice');
        } else {
            $self->{logger}->bad($publisher_connect_generic_message . ' : ' . $@ . '.', 'warn');
        }
    } else {
        $self->{logger}->bad($publisher_connect_generic_message . ' : seem already connected.', 'notice');
    }

    $self;
}

sub connect_publishers {
    my $self = shift;

    $self->connect_publisher($_->{definition}->{name}) for (@{$self->{publishers}});

    $self;
}

sub register_publisher {
    my $self = shift;

    my $publisher = $self->publisher_by_definition_name(shift);

    croak('undefined definition') unless (defined $publisher);

    $self->{cron}->add(
        $publisher->{definition}->{scheduling},
        name => 'publisher_' . $publisher->{definition}->{name},
        single => 1,
        sub {
            local $@;

            my $publish_generic_message = 'Publish events for publisher ' . $publisher->{definition}->{name};

            if (my @queue = @{$publisher->{queue}}) {
                if ($publisher->is_connected()) {
                    if (my @channels = values %{$publisher->{net}->channels()}) {
                        $self->{logger}->push_in_queue('Clear queue for publisher ' . $publisher->{definition}->{name} . '.', 'notice');

                        $publisher->clear_queue();

                        eval {
                            for my $event (@queue) {
                                my $serialize_generic_message = 'Serialize datas for collection ' . $event->{collection};

                                my $serialized = eval {
                                    $event->serialized_datas();
                                };

                                unless ($@) {
                                    $self->{logger}->good($serialize_generic_message . '.', 'debug');

                                    my $routing_key = $event->routing_key();

                                    $self->{logger}->push_in_queue($publish_generic_message . ' : sending one event with routing key ' . $routing_key . ' to exchange ' . $publisher->{definition}->{exchange} . '.', 'debug');

                                    $channels[0]->publish(
                                        exchange => $publisher->{definition}->{exchange},
                                        routing_key => $event->routing_key(),
                                        header => {
                                            delivery_mode => $publisher->{definition}->{delivery_mode}
                                        },
                                        body => $serialized
                                    );
                                } else {
                                    $self->{logger}->bad($serialize_generic_message . ' failed : ' . $@ . '.' , 'debug');
                                }
                            }
                        };

                        if ($@) {
                            $self->{logger}->bad($publish_generic_message . ' : ' . $@ . '.', 'warn');
                        } else {
                            $self->{logger}->good($publish_generic_message . '.', 'notice');
                        }
                    } else {
                        $self->{logger}->bad($publish_generic_message . ' : publisher has no channel opened.', 'warn');
                    }
                } else {
                    $self->{logger}->push_in_queue($publish_generic_message . ' : publisher is not connected.', 'notice');
                }
            } else {
                $self->{logger}->push_in_queue('Buffer for publisher ' . $publisher->{definition}->{name} . ' is empty.', 'info');
            }
        }
    );

    $self;
}

sub register_publishers {
    my $self = shift;

    $self->register_publisher($_->{definition}->{name}) for (@{$self->{publishers}});

    $self;
}

sub disconnect_publisher {
    my $self = shift;

    my $publisher = $self->publisher_by_definition_name(shift);

    croak('undefined definition') unless (defined $publisher);

    my $disconnect_generic_message = 'Disconnect publisher ' . $publisher->{definition}->{name};

    if ($publisher->is_connected()) {
        eval {
            $publisher->disconnect();
        };

        unless ($@) {
            $self->{logger}->good($disconnect_generic_message . '.', 'notice');
        } else {
            $self->{logger}->bad($disconnect_generic_message . ' : ' . $@ . '.', 'warn');
        }
    } else {
        $self->{logger}->bad($disconnect_generic_message . ' : seem already disconnected.', 'notice');
    }

    $self;
}

sub disconnect_publishers {
    my $self = shift;

    $self->disconnect_publisher($_->{name}) for (@{$self->{publishers}});

    $self;
}

sub unregister_job_by_name {
    my ($self, $job_name) = @_;

    my $jobs = $self->{cron}->jobs();

    for my $job_id (keys %{$jobs}) {
        return $self->{cron}->delete($job_id) if ($jobs->{$job_id}->{name} eq $job_name);
    }
}

sub start {
    my $self = shift;

    $self->{cron}->start()->recv();

    $self;
}

sub stop {
    my $self = shift;

    $self->{cron}->stop();

    $self;
}

sub publisher_by_definition_name {
    my ($self, $definition_name) = @_;

    for (@{$self->{publishers}}) {
        return $_ if ($_->{definition}->{name} eq $definition_name);
    }

    undef;
}

sub delete_publisher_by_definition_name {
    my ($self, $definition_name) = @_;

    my $definition_to_delete_index = 0;

    my $finded;

    $definition_to_delete_index++ until ($finded = $self->{publishers}->[$definition_to_delete_index]->{definition}->{name} eq $definition_name);

    croak($self->{definition_package} . ' : definition ' . $definition_name . ' does not exists') unless ($finded);

    eval {
        $self->{publishers}->[$definition_to_delete_index]->disconnect(); # work around, DESTROY with disconnect() inside does not work
    };

    splice @{$self->{publishers}}, $definition_to_delete_index, 1;

    $self->{rabbitmq}->delete_definition($definition_name);
}

# sub AUTOLOAD {}

# sub DESTROY {}

1;

#-> END

__END__

=pod

=head1 NAME

Navel::Scheduler::Core

=head1 AUTHOR

Yoann Le Garff, Nicolas Boquet and Yann Le Bras

=head1 LICENSE

GNU GPL v3

=cut
