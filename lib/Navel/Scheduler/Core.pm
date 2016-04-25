# Copyright 2015 Navel-IT
# navel-scheduler is developed by Yoann Le Garff, Nicolas Boquet and Yann Le Bras under GNU GPL v3

#-> BEGIN

#-> initialization

package Navel::Scheduler::Core 0.1;

use Navel::Base;

use AnyEvent;
use EV;
use AnyEvent::Fork;
use AnyEvent::IO;

use Navel::Logger::Message;
use Navel::AnyEvent::Pool;
use Navel::Scheduler::Core::Fork;
use Navel::Broker::Client::Fork;
use Navel::Utils 'croak';

#-> methods

sub new {
    my ($class, %options) = @_;

    my $self = {
        configuration => $options{configuration},
        collectors => $options{collectors},
        publishers => $options{publishers},
        runtime_per_publisher => [],
        logger => $options{logger},
        logger_callbacks => {},
        ae_condvar => AnyEvent->condvar(),
        ae_fork => AnyEvent::Fork->new()
    };

    $self->{job_types} = {
        logger => Navel::AnyEvent::Pool->new(),
        collector => Navel::AnyEvent::Pool->new(
            logger => $self->{logger},
            maximum => $self->{configuration}->{definition}->{collectors}->{maximum},
            maximum_simultaneous_exec => $self->{configuration}->{definition}->{collectors}->{maximum_simultaneous_exec}
        ),
        publisher => Navel::AnyEvent::Pool->new(
            logger => $self->{logger},
            maximum => $self->{configuration}->{definition}->{publishers}->{maximum},
            maximum_simultaneous_exec => $self->{configuration}->{definition}->{publishers}->{maximum_simultaneous_exec}
        )
    };

    bless $self, ref $class || $class;
}

sub register_core_logger {
    my $self = shift;

    my $job_name = 0;

    $self->unregister_job_by_type_and_name('logger', $job_name);

    $self->pool_matching_job_type('logger')->attach_timer(
        name => $job_name,
        singleton => 1,
        interval => 0.1,
        on_disabled => sub {
            $self->{logger}->clear_queue()
        },
        callback => sub {
            my $timer = shift;

            $timer->begin();

            $_->($self->{logger}) for values %{$self->{logger_callbacks}};

            $self->{logger}->flush_queue(
                async => 1
            );

            $timer->end();
        }
    );

    $self;
}

my $register_collector_by_name_common_workflow = sub {
    my ($self, %options) = @_;

    my $on_event_error_message_prefix = 'incorrect declaration in collector ' . $options{collector}->{name};

    Navel::Scheduler::Core::Fork->new(
        core => $self,
        collector => $options{collector},
        collector_content => $options{collector_content},
        on_event => sub {
            local $@;

            for (@_) {
                if (ref $_ eq 'ARRAY') {
                    if (defined $_->[0]) {
                        $_->[0] = int $_->[0];

                        if ($_->[0] == Navel::Scheduler::Core::Fork::EVENT_EVENT) {
                            eval {
                                $self->goto_collector_next_stage(
                                    public_interface => 1,
                                    collector => $options{collector},
                                    status => $_->[1],
                                    starting_time => $options{collector_starting_time},
                                    data => $_->[2]
                                );
                            };
                        } elsif ($_->[0] == Navel::Scheduler::Core::Fork::EVENT_LOG) {
                            eval {
                                $self->{logger}->push_in_queue(
                                    severity => $_->[1],
                                    text => 'collector ' . $options{collector}->{name} . ': ' . $_->[2]
                                ) if defined $_->[2];
                            };
                        } else {
                            $self->{logger}->err($on_event_error_message_prefix . ': unknown event type');
                        }

                        $self->{logger}->err(
                            Navel::Logger::Message->stepped_message($on_event_error_message_prefix . '.',
                                [
                                    $@
                                ]
                            )
                        ) if $@;
                    } else {
                        $self->{logger}->err($on_event_error_message_prefix . ': event type must be defined.');
                    }
                } else {
                    $self->{logger}->err($on_event_error_message_prefix . ': event must be a ARRAY reference.');
                }
            }
        },
        on_error => sub {
            $self->{logger}->err('execution of collector ' . $options{collector}->{name} . ' failed (fatal error): ' . shift . '.');

            $self->goto_collector_next_stage(
                job => $options{job},
                collector => $options{collector},
                status => '__KO',
                starting_time => $options{collector_starting_time}
            );
        },
        on_destroy => sub {
            $self->{logger}->notice('collector ' . $options{collector}->{name} . ' is destroyed.');
        }
    )->when_done(
        callback => sub {
            $self->goto_collector_next_stage(
                job => $options{job}
            );
        }
    );

    $self;
};

sub register_collector_by_name {
    my $self = shift;

    my $collector = $self->{collectors}->definition_by_name(shift);

    croak('unknown collector') unless defined $collector;

    $self->unregister_job_by_type_and_name('collector', $collector->{name});

    $self->pool_matching_job_type('collector')->attach_timer(
        name => $collector->{name},
        singleton => $collector->{singleton},
        interval => $collector->{scheduling},
        splay => 1,
        callback => sub {
            my $timer = shift;

            $timer->begin();

            local $!;

            my $collector_starting_time = time;

            if ($collector->is_type_pm()) {
                $self->$register_collector_by_name_common_workflow(
                    job => $timer,
                    collector => $collector,
                    collector_starting_time => $collector_starting_time
                );
            } else {
                aio_load($self->{configuration}->{definition}->{collectors}->{collectors_exec_directory} . '/' . $collector->resolve_basename(),
                    sub {
                        my $collector_content = shift;

                        if (defined $collector_content) {
                            $self->$register_collector_by_name_common_workflow(
                                job => $timer,
                                collector => $collector,
                                collector_content => $collector_content,
                                collector_starting_time => $collector_starting_time
                            );
                        } else {
                            $self->{logger}->err(
                                Navel::Logger::Message->stepped_message('collector ' . $collector->{name} . '.',
                                    [
                                        $!
                                    ]
                                )
                            );

                            $self->goto_collector_next_stage(
                                job => $timer,
                                collector_name => $collector->{name},
                                collector => $collector,
                                status => '__KO',
                                starting_time => $collector_starting_time
                            );
                        }
                    }
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

    my $publisher_definition = $self->{publishers}->definition_by_name(shift);

    croak('unknown publisher') unless defined $publisher_definition;

    $self->{logger}->notice('initialize publisher ' . $publisher_definition->{name} . '.');

    my $on_event_error_message_prefix = 'incorrect declaration in publisher ' . $publisher_definition->{name};

    push @{$self->{runtime_per_publisher}}, Navel::Broker::Client::Fork->new(
        logger => $self->{logger},
        definition => $publisher_definition,
        ae_fork => $self->{ae_fork},
        on_event => sub {
            local $@;

            for (@_) {
                if (ref $_ eq 'ARRAY') {
                    eval {
                        $self->{logger}->push_in_queue(
                            severity => $_->[0],
                            text => 'publisher ' . $publisher_definition->{name} . ': ' . $_->[1]
                        ) if defined $_->[1];
                    };

                    $self->{logger}->err(
                        Navel::Logger::Message->stepped_message($on_event_error_message_prefix . '.',
                            [
                                $@
                            ]
                        )
                    ) if $@;
                } else {
                    $self->{logger}->err($on_event_error_message_prefix . ': event must be a ARRAY reference.');
                }
            }
        },
        on_error => sub {
            $self->{logger}->err('execution of publisher ' . $publisher_definition->{name} . ' failed (fatal error): ' . shift . '.');
        },
        on_destroy => sub {
            $self->{logger}->notice('publisher ' . $publisher_definition->{name} . ' is destroyed.');
        }
    );

    $self;
}

sub init_publishers {
    my $self = shift;

    $self->init_publisher_by_name($_->{name}) for @{$self->{publishers}->{definitions}};

    $self;
}

sub connect_publisher_by_name {
    my $self = shift;

    my $publisher = $self->publisher_runtime_by_name(shift);

    croak('unknown publisher') unless defined $publisher;

    my $connect_generic_message = 'connect publisher ' . $publisher->{definition}->{name};

    if ($publisher->{definition}->{connectable}) {
        $publisher->rpc(
            method => 'is_connected',
            options => [
                $publisher->{definition}
            ],
            callback => sub {
                if (shift) {
                    $self->{logger}->warning($connect_generic_message . ': already connected.');
                } else {
                    $publisher->rpc(
                        method => 'is_connecting',
                        options => [
                            $publisher->{definition}
                        ],
                        callback => sub {
                            if (shift) {
                                $self->{logger}->warning($connect_generic_message . ': already trying to establish a connection.');
                            } else {
                                $self->{logger}->notice($connect_generic_message . '.');

                                $publisher->rpc(
                                    method => 'connect',
                                    options => [
                                        $publisher->{definition}
                                    ],
                                    callback => sub {
                                    }
                                );
                            }
                        }
                    );
                }
            }
        );
    } else {
        $self->{logger}->debug($connect_generic_message . ': nothing to connect.');
    }

    $self;
}

sub connect_publishers {
    my $self = shift;

    $self->connect_publisher_by_name($_->{name}) for @{$self->{publishers}->{definitions}};

    $self;
}

sub disconnect_publisher_by_name {
    my $self = shift;

    my $publisher = $self->publisher_runtime_by_name(shift);

    croak('unknown publisher') unless defined $publisher;

    my $disconnect_generic_message = 'disconnect publisher ' . $publisher->{definition}->{name};

    if ($publisher->{definition}->{connectable}) {
        $publisher->rpc(
            method => 'is_disconnected',
            options => [
                $publisher->{definition}
            ],
            callback => sub {
                if (shift) {
                    $self->{logger}->warning($disconnect_generic_message . ': already disconnected.')
                } else {
                    $publisher->rpc(
                        method => 'is_disconnecting',
                        options => [
                            $publisher->{definition}
                        ],
                        callback => sub {
                            if (shift) {
                                $self->{logger}->warning($disconnect_generic_message . ': already trying to disconnect.');
                            } else {
                                $self->{logger}->notice($disconnect_generic_message . '.');

                                $publisher->rpc(
                                    method => 'disconnect',
                                    options => [
                                        $publisher->{definition}
                                    ],
                                    callback => sub {
                                    }
                                );
                            }
                        }
                    );
                }
            }
        );
    } else {
        $self->{logger}->debug($disconnect_generic_message . ': nothing to disconnect');
    }

    $self;
}

sub disconnect_publishers {
    my $self = shift;

    $self->disconnect_publisher_by_name($_->{name}) for @{$self->{publishers}->{definitions}};

    $self;
}

my $register_publisher_by_name_common_workflow = sub {
    my ($self, %options) = @_;

    local $@;

    my (@serialized_events, @serialization_errors);

    for (@{$options{publisher}->{queue}}) {
        eval {
            push @serialized_events, $_->serialize();
        };

        push @serialization_errors, $@ if $@;
    }

    $self->{logger}->err(
        Navel::Logger::Message->stepped_message('error(s) occurred while serializing the events currently in the queue of publisher ' . $options{publisher}->{definition}->{name} . '.', \@serialization_errors)
    ) if @serialization_errors;

    $self->{logger}->debug('clear queue for publisher ' . $options{publisher}->{definition}->{name} . '.');

    $options{publisher}->clear_queue();

    if (@serialized_events) {
        $self->{logger}->debug('publisher ' . $options{publisher}->{definition}->{name} . ': trying to publicate the events properly serialized.');

        $options{publisher}->rpc(
            method => 'publish',
            options => [
                $options{publisher}->{definition},
                \@serialized_events
            ],
            callback => sub {
                $options{job}->end();
            }
        );
    } else {
        $self->{logger}->debug('publisher ' . $options{publisher}->{definition}->{name} . ': there are no events correctly serialized to publish.');

        $options{job}->end();
    }

    $self;
};

sub register_publisher_by_name {
    my $self = shift;

    my $publisher = $self->publisher_runtime_by_name(shift);

    croak('unknown publisher') unless defined $publisher;

    $self->unregister_job_by_type_and_name('publisher', $publisher->{definition}->{name});

    my $generic_message = 'publisher ' . $publisher->{definition}->{name};

    my $publish_generic_message = 'publish events for ' . $generic_message;

    $self->pool_matching_job_type('publisher')->attach_timer(
        name => $publisher->{definition}->{name},
        singleton => 1,
        interval => $publisher->{definition}->{scheduling},
        splay => 1,
        callback => sub {
            my $timer = shift;

            $timer->begin();

            if ($publisher->{definition}->{connectable} && $publisher->{definition}->{auto_connect}) {
                $publisher->rpc(
                    method => 'is_connected',
                    options => [
                        $publisher->{definition}
                    ],
                    callback => sub {
                        unless (shift) {
                            $publisher->rpc(
                                method => 'is_connecting',
                                options => [
                                    $publisher->{definition}
                                ],
                                callback => sub {
                                    $self->connect_publisher_by_name($publisher->{definition}->{name}) unless shift;
                                }
                            );
                        }
                    }
                );
            }

            if (@{$publisher->{queue}}) {
                if ($publisher->{definition}->{connectable}) {
                    $publisher->rpc(
                        method => 'is_connected',
                        options => [
                            $publisher->{definition}
                        ],
                        callback => sub {
                            if (shift) {
                                $self->$register_publisher_by_name_common_workflow(
                                    job => $timer,
                                    publisher => $publisher
                                );
                            } else {
                                $self->{logger}->notice($publish_generic_message . ": publisher isn't connected.");

                                $timer->end();
                            }
                        }
                    );
                } else {
                    $self->$register_publisher_by_name_common_workflow(
                        job => $timer,
                        publisher => $publisher
                    );
                }
            } else {
                $self->{logger}->debug('queue for ' . $generic_message . ' is empty.');

                $timer->end();
            }
        }
    );

    $self;
}

sub register_publishers {
    my $self = shift;

    $self->register_publisher_by_name($_->{name}) for @{$self->{publishers}->{definitions}};

    $self;
}

sub publisher_runtime_by_name {
    my ($self, $name) = @_;

    croak('name must be defined') unless defined $name;

    for (@{$self->{runtime_per_publisher}}) {
        return $_ if $_->{definition}->{name} eq $name;
    }

    undef;
}

my $delete_publisher_and_definition_associated_by_name_common_workflow = sub {
    my ($self, %options) = @_;
    
    $self->unregister_job_by_type_and_name('publisher', $self->{runtime_per_publisher}->[$options{definition_to_delete_index}]->{definition}->{name});

    $self->{runtime_per_publisher}->[$options{definition_to_delete_index}]->exit();

    splice @{$self->{runtime_per_publisher}}, $options{definition_to_delete_index}, 1;

    $self->{publishers}->delete_definition(
        definition_name => $options{definition_name}
    );

    $self;
};

sub delete_publisher_and_definition_associated_by_name {
    my ($self, $name) = @_;

    croak('name must be defined') unless defined $name;

    my $finded;

    my $definition_to_delete_index = 0;

    $definition_to_delete_index++ until $finded = $self->{runtime_per_publisher}->[$definition_to_delete_index]->{definition}->{name} eq $name;

    die $self->{definition_class} . ': definition ' . $name . " does not exists\n" unless $finded;

    if ($self->{runtime_per_publisher}->[$definition_to_delete_index]->{definition}->{connectable}) {
        $self->{runtime_per_publisher}->[$definition_to_delete_index]->rpc(
            method => 'disconnect',
            options => [
                $self->{runtime_per_publisher}->[$definition_to_delete_index]->{definition}
            ],
            callback => sub {
                $self->$delete_publisher_and_definition_associated_by_name_common_workflow(
                    definition_to_delete_index => $definition_to_delete_index,
                    definition_name => $name
                );
            }
        );
    } else {
        $self->$delete_publisher_and_definition_associated_by_name_common_workflow(
            definition_to_delete_index => $definition_to_delete_index,
            definition_name => $name
        );
    }

    $self;
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
    my $job = shift->job_by_type_and_name(@_);

    $job->DESTROY() if defined $job;
}

sub goto_collector_next_stage {
    my ($self, %options) = @_;

    my $job = delete $options{job};

    if (%options) {
        for (@{$self->{runtime_per_publisher}}) {
            $_->push_in_queue(\%options);

            $self->{logger}->info('publisher ' . $_->{definition}->{name} . ': add an event from collector ' . $options{collector}->{name} . '.');
        }
    }

    $job->end() if defined $job;

    $self;
}

sub recv {
    my $self = shift;

    $self->{ae_condvar}->recv();

    $self;
}

sub send {
    my $self = shift;

    $self->{ae_condvar}->send();

    $self;
}

# sub AUTOLOAD {}

# sub DESTROY {}

1;

#-> END

__END__

=pod

=encoding utf8

=head1 NAME

Navel::Scheduler::Core

=head1 AUTHOR

Yoann Le Garff, Nicolas Boquet and Yann Le Bras

=head1 LICENSE

GNU GPL v3

=cut
