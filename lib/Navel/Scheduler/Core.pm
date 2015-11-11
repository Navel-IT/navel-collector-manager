# Copyright 2015 Navel-IT
# navel-scheduler is developed by Yoann Le Garff, Nicolas Boquet and Yann Le Bras under GNU GPL v3

#-> BEGIN

#-> initialization

package Navel::Scheduler::Core;

use strict;
use warnings;

use feature 'state';

use parent 'Navel::Base';

use constant {
    COLLECTOR_JOB_PREFIX => 'collector_',
    PUBLISHER_JOB_PREFIX => 'publisher_',
    LOGGER_JOB_PREFIX => 'logger_'
};

use AnyEvent::DateTime::Cron;
use AnyEvent::IO;

use Navel::Scheduler::Core::Fork;
use Navel::RabbitMQ::Publisher;
use Navel::RabbitMQ::Serialize::Data 'to';
use Navel::Utils 'blessed';

our $VERSION = 0.1;

#-> methods

sub new {
    my ($class, %options) = @_;

    bless {
        configuration => $options{configuration},
        collectors => $options{collectors},
        rabbitmq => $options{rabbitmq},
        publishers => [],
        logger => $options{logger},
        cron => AnyEvent::DateTime::Cron->new(
            quartz => 1
        ),
        jobs => {
            enabled => {},
            collectors => {
                running => {}
            }
        }
    }, ref $class || $class;
}

sub register_the_logger {
    my $self = shift;

    my $job_name = LOGGER_JOB_PREFIX . '0';

    $self->{jobs}->{enabled}->{$job_name} = 1;

    $self->{cron}->add(
        '*/1 * * * * ?',
        name => $job_name,
        single => 1,
        sub {
            $self->{logger}->flush_queue(
                async => 1
            ) if $self->{jobs}->{enabled}->{$job_name};
        }
    );

    $self;
}

sub register_collector_by_name {
    my $self = shift;

    my $collector = $self->{collectors}->definition_by_name(shift);

    my $job_name = COLLECTOR_JOB_PREFIX . $collector->{name};

    $self->{jobs}->{enabled}->{$job_name} = 1;
    $self->{jobs}->{collectors}->{running}->{$collector->{name}} = 0;

    $self->{cron}->add(
        $collector->{scheduling},
        name => $job_name,
        single => 1,
        sub {
            local ($@, $!);

            if ($self->{jobs}->{enabled}->{$job_name}) {
                unless ($self->{configuration}->{definition}->{collectors}->{maximum_simultaneous_exec} && $self->count_collectors_running() >= $self->{configuration}->{definition}->{collectors}->{maximum_simultaneous_exec}) {
                    unless ($collector->{singleton} && $self->{jobs}->{collectors}->{running}->{$collector->{name}}) {
                        $self->{jobs}->{collectors}->{running}->{$collector->{name}}++;

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
                                        message => 'Execution of collector ' . $collector->{name} . ' failed (fatal error): ' . shift() . '.',
                                        severity => 'error'
                                    );

                                    $self->a_collector_stop(
                                        collector => $collector,
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
                                        collector => $collector,
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
                                        message => 'Collector ' . $collector->{name} . ': ' . $! . '.',
                                        severity => 'error'
                                    );

                                    $self->a_collector_stop(
                                        collector => $collector,
                                        event_definition => {
                                            collector => $collector,
                                            starting_time => $collector_starting_time
                                        },
                                        status_method => 'set_status_to_ko_no_source'
                                    );
                                }
                            });
                        }
                    } else {
                        $self->{logger}->push_in_queue(
                            message => 'Collector ' . $collector->{name} . ' is already running.',
                            severity => 'info'
                        );
                    }
                } else {
                    $self->{logger}->push_in_queue(
                        message => 'Too much collectors are running (maximum of ' . $self->{configuration}->{definition}->{collectors}->{maximum_simultaneous_exec} . ').',
                        severity => 'info'
                    );
                }
            } else {
                $self->{logger}->push_in_queue(
                    message => 'Job ' . $job_name . ' is disabled.',
                    severity => 'info'
                );
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

    $self->{logger}->push_in_queue(
        message => 'Initialize publisher ' . $rabbitmq->{name} . '.',
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

    my $publisher_connect_generic_message = 'Connect publisher ' . $publisher->{definition}->{name};

    unless ($publisher->is_connected()) {
        my $publisher_generic_message = 'Publisher ' . $publisher->{definition}->{name};

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
                                        $publisher_generic_message . ': channel failure ... ',
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
                                $publisher_connect_generic_message . ': failure ... ',
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
                                $publisher_generic_message . ': read failure ... ',
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
            message => $publisher_connect_generic_message . ': seem already connected.',
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

sub register_publisher_by_name {
    my $self = shift;

    my $publisher = $self->publisher_by_name(shift);

    my $job_name = PUBLISHER_JOB_PREFIX . $publisher->{definition}->{name};

    $self->{jobs}->{enabled}->{$job_name} = 1;

    $self->{cron}->add(
        $publisher->{definition}->{scheduling},
        name => $job_name,
        single => 1,
        sub {
            local $@;

            if ($self->{jobs}->{enabled}->{$job_name}) {
                my $publish_generic_message = 'Publish events for publisher ' . $publisher->{definition}->{name};

                if (my @queue = @{$publisher->{queue}}) {
                    if ($publisher->is_connected()) {
                        if (my @channels = values %{$publisher->{net}->channels()}) {
                            $self->{logger}->push_in_queue(
                                message => 'Clear queue for publisher ' . $publisher->{definition}->{name} . '.',
                                severity => 'info'
                            );

                            $publisher->clear_queue();

                            eval {
                                for (@queue) {
                                    my $serialize_generic_message = 'Serialize datas for collection ' . $_->{collection};

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
                        message => 'Queue for publisher ' . $publisher->{definition}->{name} . ' is empty.',
                        severity => 'info'
                    );
                }
            } else {
                $self->{logger}->push_in_queue(
                    message => 'Job ' . $job_name . ' is disabled.',
                    severity => 'info'
                );
            }
        }
    );

    $self;
}

sub register_publishers {
    my $self = shift;

    $self->register_publisher_by_name($_->{definition}->{name}) for @{$self->{publishers}};

    $self;
}

sub disconnect_publisher_by_name {
    my $self = shift;

    my $publisher = $self->publisher_by_name(shift);

    my $disconnect_generic_message = 'Disconnect publisher ' . $publisher->{definition}->{name};

    if ($publisher->is_connected()) {
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
            message => $disconnect_generic_message . ': seem already disconnected.',
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

sub publisher_by_name {
    my ($self, $name) = @_;

    for (@{$self->{publishers}}) {
        return $_ if $_->{definition}->{name} eq $name;
    }

    undef;
}

sub delete_publisher_by_name {
    my ($self, $name) = @_;

    my $finded;

    my $definition_to_delete_index = 0;

    $definition_to_delete_index++ until $finded = $self->{publishers}->[$definition_to_delete_index]->{definition}->{name} eq $name;

    die $self->{definition_class} . ': definition ' . $name . " does not exists\n" unless $finded;

    eval {
        $self->{publishers}->[$definition_to_delete_index]->disconnect(); # work around, DESTROY with disconnect() inside does not work
    };

    splice @{$self->{publishers}}, $definition_to_delete_index, 1;

    $self->{rabbitmq}->delete_definition(
        definition_name => $name
    );
}

sub job_types {
    my $self = shift;

    my %types;

    for (values %{$self->{cron}->jobs()}) {
        $types{$1} = undef if $_->{name} =~ /^(.*)_/;
    }

    [keys %types];
}

sub job_names_by_type {
    my ($self, $type) = @_;

    my @jobs;

    for (values %{$self->{cron}->jobs()}) {
        push @jobs, $2 if $_->{name} =~ /^($type)_(.*)/;
    }

    \@jobs;
}

sub unregister_job_by_name {
    my ($self, $name) = @_;

    my $jobs = $self->{cron}->jobs();

    for (keys %{$jobs}) {
        return $self->{cron}->delete($_) if $jobs->{$_}->{name} eq $name;
    }
}

sub a_collector_stop {
    my ($self, %options) = @_;

    my $collector = delete $options{collector};

    $self->{logger}->push_in_queue(
        message => 'Add an event from collector ' . $collector->{name} . ' in the queue of existing publishers.',
        severity => 'info'
    );

    $_->push_in_queue(%options) for @{$self->{publishers}};

    $self->{jobs}->{collectors}->{running}->{$collector->{name}}--;

    1;
}

sub count_collectors_running {
    state $sum += $_ for values %{shift->{jobs}->{collectors}->{running}};

    $sum;
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
