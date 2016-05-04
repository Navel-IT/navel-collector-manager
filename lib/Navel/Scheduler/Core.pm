# Copyright (C) 2015 Yoann Le Garff, Nicolas Boquet and Yann Le Bras
# navel-scheduler is licensed under the Apache License, Version 2.0

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
use Navel::Scheduler::Core::Collector::Fork;
use Navel::Broker::Client::Fork;
use Navel::Utils qw/
    isint
    croak
/;

#-> methods

sub new {
    my ($class, %options) = @_;

    my $self = {
        configuration => $options{configuration},
        collectors => $options{collectors},
        runtime_per_collector => {},
        publishers => $options{publishers},
        runtime_per_publisher => {},
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
    my ($self, $job_name) = (shift, 0);

    $self->unregister_job_by_type_and_name('logger', $job_name);

    $self->pool_matching_job_type('logger')->attach_timer(
        name => $job_name,
        singleton => 1,
        interval => 0.5,
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

    $self->{runtime_per_collector}->{$options{collector}->{name}} = Navel::Scheduler::Core::Collector::Fork->new(
        core => $self,
        definition => $options{collector},
        collector_content => $options{collector_content},
        on_event => sub {
            local $@;

            for (@_) {
                if (ref $_ eq 'ARRAY') {
                    if (isint($_->[0])) {
                        if ($_->[0] == Navel::Scheduler::Core::Collector::Fork::EVENT_EVENT) {
                            eval {
                                $self->goto_collector_next_stage(
                                    public_interface => 1,
                                    collector => $options{collector},
                                    status => $_->[1],
                                    starting_time => $options{collector_starting_time},
                                    data => $_->[2]
                                );
                            };
                        } elsif ($_->[0] == Navel::Scheduler::Core::Collector::Fork::EVENT_LOG) {
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
                        $self->{logger}->err($on_event_error_message_prefix . ': event type must be an integer.');
                    }
                } else {
                    $self->{logger}->err($on_event_error_message_prefix . ': event must be a ARRAY reference.');
                }
            }
        },
        on_error => sub {
            $self->{logger}->warning('execution of collector ' . $options{collector}->{name} . ' stopped (fatal): ' . shift . '.');

            $self->goto_collector_next_stage(
                job => $options{job},
                collector => $options{collector},
                status => '__KO',
                starting_time => $options{collector_starting_time}
            );
        },
        on_destroy => sub {
            $self->{logger}->info('collector ' . $options{collector}->{name} . ' is destroyed.');
        }
    )->rpc(
        callback => sub {
            $self->goto_collector_next_stage(
                job => $options{job}
            );
        }
    );

    undef $self->{runtime_per_collector}->{$options{collector}->{name}}->{rpc} unless $options{collector}->{async};

    $self;
};

sub register_collector_by_name {
    my $self = shift;

    my $collector = $self->{collectors}->definition_by_name(shift);

    die "unknown collector definition\n" unless defined $collector;

    $self->unregister_job_by_type_and_name('collector', $collector->{name});

    $self->pool_matching_job_type('collector')->attach_timer(
        name => $collector->{name},
        singleton => 1,
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
                            $self->{logger}->warning(
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

sub delete_collector_and_definition_associated_by_name {
    my $self = shift;

    my $collector = $self->{collectors}->definition_by_name(shift);

    die "unknown collector runtime\n" unless defined $collector;

    if ($collector->{async}) {
        local $@;

        eval {
            $self->{runtime_per_collector}->{$collector->{name}}->rpc(
                exit => 1
            );

            undef $self->{runtime_per_collector}->{$collector->{name}}->{rpc};
       };
    }

    $self->unregister_job_by_type_and_name('collector', $collector->{name});

    $self->{collectors}->delete_definition(
        definition_name => $collector->{name}
    );

    delete $self->{runtime_per_collector}->{$collector->{name}};

    $self;
}

sub init_publisher_by_name {
    my $self = shift;

    my $publisher = $self->{publishers}->definition_by_name(shift);

    die "unknown publisher definition\n" unless defined $publisher;

    $self->{logger}->notice('initialize publisher ' . $publisher->{name} . '.');

    my $on_event_error_message_prefix = 'incorrect declaration in publisher ' . $publisher->{name};

    $self->{runtime_per_publisher}->{$publisher->{name}} = Navel::Broker::Client::Fork->new(
        logger => $self->{logger},
        meta_configuration => $self->{configuration}->{definition}->{publishers},
        definition => $publisher,
        ae_fork => $self->{ae_fork},
        on_event => sub {
            local $@;

            for (@_) {
                if (ref $_ eq 'ARRAY') {
                    eval {
                        $self->{logger}->push_in_queue(
                            severity => $_->[0],
                            text => 'publisher ' . $publisher->{name} . ': ' . $_->[1]
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
            $self->{logger}->warning('execution of publisher ' . $publisher->{name} . ' stopped (fatal): ' . shift . '.');
        },
        on_destroy => sub {
            $self->{logger}->info('publisher ' . $publisher->{name} . ' is destroyed.');
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
    my ($self, $name) = @_;

    croak('name must be defined') unless defined $name;

    my $publisher = $self->{runtime_per_publisher}->{$name};

    die "unknown publisher runtime\n" unless defined $publisher;

    my $connect_generic_message = 'connect publisher ' . $publisher->{definition}->{name};

    if ($publisher->{definition}->{connectable}) {
        $publisher->rpc(
            method => 'is_connected',
            callback => sub {
                if (shift) {
                    $self->{logger}->warning($connect_generic_message . ': already connected.');
                } else {
                    $publisher->rpc(
                        method => 'is_connecting',
                        callback => sub {
                            if (shift) {
                                $self->{logger}->warning($connect_generic_message . ': already trying to establish a connection.');
                            } else {
                                $self->{logger}->notice($connect_generic_message . '.');

                                $publisher->rpc(
                                    method => 'connect'
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

    for (@{$self->{publishers}->{definitions}}) {
        $self->connect_publisher_by_name($_->{name}) if defined $self->{runtime_per_publisher}->{$_->{name}};
    }

    $self;
}

sub disconnect_publisher_by_name {
    my ($self, $name) = @_;

    croak('name must be defined') unless defined $name;

    my $publisher = $self->{runtime_per_publisher}->{$name};

    die "unknown publisher runtime\n" unless defined $publisher;

    my $disconnect_generic_message = 'disconnect publisher ' . $publisher->{definition}->{name};

    if ($publisher->{definition}->{connectable}) {
        $publisher->rpc(
            method => 'is_disconnected',
            callback => sub {
                if (shift) {
                    $self->{logger}->warning($disconnect_generic_message . ': already disconnected.')
                } else {
                    $publisher->rpc(
                        method => 'is_disconnecting',
                        callback => sub {
                            if (shift) {
                                $self->{logger}->warning($disconnect_generic_message . ': already trying to disconnect.');
                            } else {
                                $self->{logger}->notice($disconnect_generic_message . '.');

                                $publisher->rpc(
                                    method => 'disconnect'
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

    for (@{$self->{publishers}->{definitions}}) {
        $self->disconnect_publisher_by_name($_->{name}) if defined $self->{runtime_per_publisher}->{$_->{name}};
    }

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
    my ($self, $name) = @_;

    croak('name must be defined') unless defined $name;

    my $publisher = $self->{runtime_per_publisher}->{$name};

    die "unknown publisher runtime\n" unless defined $publisher;

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
                    callback => sub {
                        unless (shift) {
                            $publisher->rpc(
                                method => 'is_connecting',
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

sub delete_publisher_and_definition_associated_by_name {
    my $self = shift;

    my $publisher = $self->{publishers}->definition_by_name(shift);

    die "unknown publisher\n" unless defined $publisher;

    local $@;

    eval {
        $self->{runtime_per_publisher}->{$publisher->{name}}->rpc(
            exit => 1
        );
    };

    $self->unregister_job_by_type_and_name('publisher', $publisher->{name});

    $self->{publishers}->delete_definition(
        definition_name => $publisher->{name}
    );

    eval {
        undef $self->{runtime_per_publisher}->{$publisher->{name}}->{rpc};

        delete $self->{runtime_per_publisher}->{$publisher->{name}};
    };

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
    
    $self->pool_matching_job_type($type)->timers();
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
        for (values %{$self->{runtime_per_publisher}}) {
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

=head1 COPYRIGHT

Copyright (C) 2015 Yoann Le Garff, Nicolas Boquet and Yann Le Bras

=head1 LICENSE

navel-scheduler is licensed under the Apache License, Version 2.0

=cut
