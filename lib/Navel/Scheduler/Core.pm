# Copyright 2015 Navel-IT
# navel-scheduler is developed by Yoann Le Garff, Nicolas Boquet and Yann Le Bras under GNU GPL v3

#-> BEGIN

#-> initialization

package Navel::Scheduler::Core;

use strict;
use warnings;

use parent 'Navel::Base';

use Carp 'croak';

use AnyEvent;
use AnyEvent::IO;

use Navel::AnyEvent::Pool;
use Navel::Scheduler::Core::Fork;
use Navel::RabbitMQ::Publisher;

use Navel::Utils 'blessed';

our $VERSION = 0.1;

#-> methods

sub new {
    my ($class, %options) = @_;

    my $self = {
        configuration => $options{configuration},
        collectors => $options{collectors},
        rabbitmq => $options{rabbitmq},
        publishers => [],
        logger => $options{logger},
        condvar => AnyEvent->condvar()
    };

    $self->{job_types} = {
        logger => Navel::AnyEvent::Pool->new(),
        collector => Navel::AnyEvent::Pool->new(
            logger => $self->{logger},
            maximum => $self->{configuration}->{collectors}->{maximum},
            maximum_simultaneous_exec => $self->{configuration}->{collectors}->{maximum_simultaneous_exec}
        ),
        publisher => Navel::AnyEvent::Pool->new(
            logger => $self->{logger},
            maximum => $self->{configuration}->{rabbitmq}->{maximum},
            maximum_simultaneous_exec => $self->{configuration}->{rabbitmq}->{maximum_simultaneous_exec}
        )
    };

    bless $self, ref $class || $class;
}

sub register_the_logger {
    my ($self, $job_name) = @_;

    croak('job name must be defined') unless defined $job_name;

    $self->unregister_job_by_type_and_name('logger', $job_name);

    $self->pool_matching_job_type('logger')->attach_timer(
        name => $job_name,
        singleton => 1,
        interval => 0.1,
        callback => sub {
            my $timer = shift;

            $timer->begin();

            $self->{logger}->flush_queue();

            $timer->end();
        }
    );

    $self;
}

sub register_collector_by_name {
    my $self = shift;

    my $collector = $self->{collectors}->definition_by_name(shift);

    croak('unknown collector') unless defined $collector;

    $self->unregister_job_by_type_and_name('collector', $collector->{name});

    $self->pool_matching_job_type('collector')->attach_timer(
        name => $collector->{name},
        singleton => $collector->{singleton},
        interval => $collector->{scheduling},
        callback => sub {
            my $timer = shift;

            $timer->begin();

            local ($@, $!);

            my $collector_starting_time = time;

            my $fork_collector = sub {
                my $collector_content = shift;

                Navel::Scheduler::Core::Fork->new(
                    core => $self,
                    collector_execution_timeout => $self->{configuration}->{definition}->{collectors}->{execution_timeout},
                    collector => $collector,
                    collector_content => $collector_content,
                    on_event => sub {
                        $self->{logger}->push_in_queue(
                            message => 'AnyEvent::Fork::RPC event message for collector ' . $collector->{name} . ': ' . shift() . '.',
                            severity => 'notice'
                        );
                    },
                    on_error => sub {
                        $self->{logger}->push_in_queue(
                            message => 'execution of collector ' . $collector->{name} . ' failed (fatal error): ' . shift() . '.',
                            severity => 'error'
                        );

                        $self->a_collector_stop(
                            job => $timer,
                            collector_name => $collector->{name},
                            event_definition => {
                                collector => $collector,
                                starting_time => $collector_starting_time
                            },
                            status_method => 'set_status_to_ko_exception'
                        );
                    },
                    on_destroy => sub {
                        $self->{logger}->push_in_queue(
                            message => 'AnyEvent::Fork::RPC DESTROY() called for collector ' . $collector->{name} . '.',
                            severity => 'info'
                        );
                    }
                )->when_done(
                    callback => sub {
                        $self->a_collector_stop(
                            job => $timer,
                            collector_name => $collector->{name},
                            event_definition => {
                                collector => $collector,
                                starting_time => $collector_starting_time,
                                datas => shift
                            }
                        );
                    }
                );
            };

            if ($collector->is_type_package()) {
                $fork_collector->();
            } else {
                aio_load($self->{configuration}->{definition}->{collectors}->{collectors_exec_directory} . '/' . $collector->resolve_basename(), sub {
                    my ($collector_content) = @_;

                    if ($collector_content) {
                        $fork_collector->($collector_content);
                    } else {
                        $self->{logger}->push_in_queue(
                            message => 'collector ' . $collector->{name} . ': ' . $! . '.',
                            severity => 'error'
                        );

                        $self->a_collector_stop(
                            job => $timer,
                            collector_name => $collector->{name},
                            event_definition => {
                                collector => $collector,
                                starting_time => $collector_starting_time
                            },
                            status_method => 'set_status_to_ko_no_source'
                        );
                    }
                });
            }
        }
    );

    $self;
}

sub register_collectors {
    my $self = shift;

    $self->register_collector_by_name($_->{name}) for @{$self->{collectors}->{definitions}};

    $self;
}

sub init_publisher_by_name {
    my $self = shift;

    my $rabbitmq = $self->{rabbitmq}->definition_by_name(shift);

    croak('unknown rabbitmq') unless defined $rabbitmq;

    $self->{logger}->push_in_queue(
        message => 'initialize publisher ' . $rabbitmq->{name} . '.',
        severity => 'notice'
    );

    push @{$self->{publishers}}, Navel::RabbitMQ::Publisher->new(
        rabbitmq_definition => $rabbitmq
    );

    $self;
}

sub init_publishers {
    my $self = shift;

    $self->init_publisher_by_name($_->{name}) for @{$self->{rabbitmq}->{definitions}};

    $self;
}

sub connect_publisher_by_name {
    my $self = shift;

    my $publisher = $self->publisher_by_name(shift);

    croak('unknown publisher') unless defined $publisher;

    my $publisher_connect_generic_message = 'connect publisher ' . $publisher->{definition}->{name};

    unless ($publisher->is_connected()) {
        unless ($publisher->is_connecting()) {
            my $publisher_generic_message = 'publisher ' . $publisher->{definition}->{name};

            eval {
                $publisher->connect(
                    on_success => sub {
                        my $amqp_connection = shift;

                        $self->{logger}->push_in_queue(
                            message => $publisher_connect_generic_message . ' successfully connected.',
                            severity => 'notice'
                        );

                        $amqp_connection->open_channel(
                            on_success => sub {
                                $self->{logger}->push_in_queue(
                                    message => $publisher_generic_message . ': channel opened.',
                                    severity => 'notice'
                                );
                            },
                            on_failure => sub {
                                $self->{logger}->push_in_queue(
                                    message => $self->{logger}->stepped_log(
                                        [
                                            $publisher_generic_message . ': channel failure.',
                                            \@_
                                        ]
                                    ),
                                    severity => 'error'
                                );
                            },
                            on_close => sub {
                                $self->{logger}->push_in_queue(
                                    message => $publisher_generic_message . ': channel closed.',
                                    severity => 'notice'
                                );

                                $publisher->disconnect();
                            }
                        );
                    },
                    on_failure => sub {
                        $self->{logger}->push_in_queue(
                            message => $self->{logger}->stepped_log(
                                [
                                    $publisher_connect_generic_message . ': failure.',
                                    \@_
                                ]
                            ),
                            severity => 'error'
                        );
                    },
                    on_read_failure => sub {
                        $self->{logger}->push_in_queue(
                            message => $self->{logger}->stepped_log(
                                [
                                    $publisher_generic_message . ': read failure.',
                                    \@_
                                ]
                            ),
                            severity => 'error'
                        );
                    },
                    on_return => sub {
                        $self->{logger}->push_in_queue(
                            message => $publisher_generic_message . ': unable to deliver frame.',
                            severity => 'error'
                        );
                    },
                    on_close => sub {
                        $self->{logger}->push_in_queue(
                            message => $publisher_generic_message . ' disconnected.',
                            severity => 'notice'
                        );
                    }
                );
            };

            unless ($@) {
                $self->{logger}->push_in_queue(
                    message => $publisher_connect_generic_message . ' ....',
                    severity => 'notice'
                );
            } else {
                $self->{logger}->push_in_queue(
                    message => $self->{logger}->stepped_log(
                        [
                            $publisher_connect_generic_message . ':',
                            $@
                        ]
                    ),
                    severity => 'error'
                );
            }
        } else {
            $self->{logger}->push_in_queue(
                message => $publisher_connect_generic_message . ': already trying to establish a connection.',
                severity => 'warning'
            );
        }
    } else {
        $self->{logger}->push_in_queue(
            message => $publisher_connect_generic_message . ': already connected.',
            severity => 'warning'
        );
    }

    $self;
}

sub connect_publishers {
    my $self = shift;

    $self->connect_publisher_by_name($_->{definition}->{name}) for @{$self->{publishers}};

    $self;
}

sub disconnect_publisher_by_name {
    my $self = shift;

    my $publisher = $self->publisher_by_name(shift);

    croak('unknown publisher') unless defined $publisher;

    my $disconnect_generic_message = 'disconnect publisher ' . $publisher->{definition}->{name};

    if ($publisher->is_connected()) {
        unless ($publisher->is_disconnecting()) {
            eval {
                $publisher->disconnect();
            };

            unless ($@) {
                $self->{logger}->push_in_queue(
                    message => $disconnect_generic_message . '.',
                    severity => 'notice'
                );
            } else {
                $self->{logger}->push_in_queue(
                    message => $disconnect_generic_message . ': ' . $@ . '.',
                    severity => 'error'
                );
            }
        } else {
            $self->{logger}->push_in_queue(
                message => $disconnect_generic_message . ': already trying to disconnect.',
                severity => 'warning'
            );
        }
    } else {
        $self->{logger}->push_in_queue(
            message => $disconnect_generic_message . ': already disconnected.',
            severity => 'warning'
        );
    }

    $self;
}

sub disconnect_publishers {
    my $self = shift;

    $self->disconnect_publisher_by_name($_->{name}) for @{$self->{publishers}};

    $self;
}

sub register_publisher_by_name {
    my $self = shift;

    my $publisher = $self->publisher_by_name(shift);

    croak('unknown publisher') unless defined $publisher;

    $self->unregister_job_by_type_and_name('publisher', $publisher->{definition}->{name});

    $self->pool_matching_job_type('publisher')->attach_timer(
        name => $publisher->{definition}->{name},
        singleton => 1,
        interval => $publisher->{definition}->{scheduling},
        callback => sub {
            my $timer = shift;

            $timer->begin();

            local $@;

            if ($publisher->{definition}->{auto_connect}) {
                $self->connect_publisher_by_name($publisher->{definition}->{name}) unless $publisher->is_connected() || $publisher->is_connecting();
            }

            if (my @queue = @{$publisher->{queue}}) {
                my $publish_generic_message = 'publish events for publisher ' . $publisher->{definition}->{name};

                if ($publisher->is_connected()) {
                    if (my @channels = values %{$publisher->{net}->channels()}) {
                        $self->{logger}->push_in_queue(
                            message => 'clear queue for publisher ' . $publisher->{definition}->{name} . '.',
                            severity => 'info'
                        );

                        $publisher->clear_queue();

                        eval {
                            for (@queue) {
                                my $serialize_generic_message = 'serialize datas for collection ' . $_->{collection};

                                my $serialized = eval {
                                    $_->serialized_datas();
                                };

                                unless ($@) {
                                    $self->{logger}->push_in_queue(
                                        message => $self->{logger}->stepped_log(
                                            [
                                                $serialize_generic_message,
                                                $serialized
                                            ]
                                        ),
                                        severity => 'debug'
                                    );

                                    $self->{logger}->push_in_queue(
                                        message => $serialize_generic_message . '.',
                                        severity => 'info'
                                    );

                                    my $routing_key = $_->routing_key();

                                    $self->{logger}->push_in_queue(
                                        message => $publish_generic_message . ': sending one event with routing key ' . $routing_key . ' to exchange ' . $publisher->{definition}->{exchange} . '.',
                                        severity => 'info'
                                    );

                                    $channels[0]->publish(
                                        exchange => $publisher->{definition}->{exchange},
                                        routing_key => $_->routing_key(),
                                        header => {
                                            delivery_mode => $publisher->{definition}->{delivery_mode}
                                        },
                                        body => $serialized
                                    );
                                } else {
                                    $self->{logger}->push_in_queue(
                                        message => $serialize_generic_message . ' failed: ' . $@ . '.' ,
                                        severity => 'error'
                                    );
                                }
                            }
                        };

                        if ($@) {
                            $self->{logger}->push_in_queue(
                                message => $self->{logger}->stepped_log(
                                    [
                                        $publish_generic_message . ':',
                                        $@
                                    ]
                                ),
                                severity => 'error'
                            );
                        } else {
                            $self->{logger}->push_in_queue(
                                message => $publish_generic_message . '.',
                                severity => 'notice'
                            );
                        }
                    } else {
                        $self->{logger}->push_in_queue(
                            message => $publish_generic_message . ': publisher has no channel opened.',
                            severity => 'error'
                        );
                    }
                } else {
                    $self->{logger}->push_in_queue(
                        message => $publish_generic_message . ": publisher isn't connected.",
                        severity => 'notice'
                    );
                }
            } else {
                $self->{logger}->push_in_queue(
                    message => 'queue for publisher ' . $publisher->{definition}->{name} . ' is empty.',
                    severity => 'info'
                );
            }

            $timer->end();
        }
    );

    $self;
}

sub register_publishers {
    my $self = shift;

    $self->register_publisher_by_name($_->{definition}->{name}) for @{$self->{publishers}};

    $self;
}

sub publisher_by_name {
    my ($self, $name) = @_;

    croak('name must be defined') unless defined $name;

    for (@{$self->{publishers}}) {
        return $_ if $_->{definition}->{name} eq $name;
    }

    undef;
}

sub delete_publisher_and_definition_associated_by_name {
    my ($self, $name) = @_;

    croak('name must be defined') unless defined $name;

    my $finded;

    my $definition_to_delete_index = 0;

    $definition_to_delete_index++ until $finded = $self->{publishers}->[$definition_to_delete_index]->{definition}->{name} eq $name;

    die $self->{definition_class} . ': definition ' . $name . " does not exists\n" unless $finded;

    eval {
        $self->{publishers}->[$definition_to_delete_index]->disconnect(); # workaround, DESTROY with disconnect() inside does not work
    };

    splice @{$self->{publishers}}, $definition_to_delete_index, 1;

    $self->{rabbitmq}->delete_definition(
        definition_name => $name
    );
}

sub job_type_exists {
    my ($self, $type) = @_;

    croak('a job type must be defined') unless defined $type;

    exists $self->{job_types}->{$type};
}

sub pool_matching_job_type {
    my ($self, $type) = @_;

    croak('incorrect job type') unless $self->job_type_exists($type);

    $self->{job_types}->{$type};
}

sub jobs_by_type {
    my ($self, $type) = @_;

    croak('a job type must be defined') unless defined $type;

    my @jobs;

    push @jobs, $_ for @{$self->pool_matching_job_type($type)->timers()};

    \@jobs;
}

sub job_by_type_and_name {
    my ($self, $type, $name) = @_;

    croak('a job type and name must be defined') unless defined $type && defined $name;

    for (@{$self->jobs_by_type($type)}) {
        return $_ if $_->{name} eq $name;
    }

    undef;
}

sub unregister_job_by_type_and_name {
    my $self = shift;

    my $job = $self->job_by_type_and_name(@_);

    $job->DESTROY() if defined $job;
}

sub a_collector_stop {
    my ($self, %options) = @_;

    my $collector_name = delete $options{collector_name};

    croak('collector_name must be defined') unless defined $collector_name;

    $self->{logger}->push_in_queue(
        message => 'add an event from collector ' . $collector_name . ' in the queue of existing publishers.',
        severity => 'info'
    );

    $_->push_in_queue(%options) for @{$self->{publishers}};

    $options{job}->end() if defined $options{job};

    1;
}

sub start {
    my $self = shift;

    $self->{condvar}->recv();

    $self;
}

sub stop {
    my $self = shift;

    $self->{condvar}->send();

    $self;
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
