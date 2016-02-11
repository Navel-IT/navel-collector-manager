# Copyright 2015 Navel-IT
# navel-scheduler is developed by Yoann Le Garff, Nicolas Boquet and Yann Le Bras under GNU GPL v3

#-> BEGIN

#-> initialization

package Navel::Scheduler::Core 0.1;

use Navel::Base;

use Carp 'croak';

use AnyEvent;
use AnyEvent::Fork;
use AnyEvent::IO;

use Navel::AnyEvent::Pool;
use Navel::Scheduler::Core::Fork;
use Navel::Broker::Publisher;

use Navel::Utils 'blessed';

#-> functions

my $publisher_logger = sub {
    my ($self, $generic_message, $severity, $message) = @_;

    $self->{logger}->push_in_queue(
        severity => $severity,
        message => $self->{logger}->stepped_log($generic_message . '.',
            [
               $message
            ]
        )
    ) if defined $message;
};

#-> methods

sub new {
    my ($class, %options) = @_;

    my $self = {
        configuration => $options{configuration},
        collectors => $options{collectors},
        publishers => $options{publishers},
        runtime_per_publisher => [],
        logger => $options{logger},
        ae_condvar => AnyEvent->condvar(),
        ae_fork => AnyEvent::Fork->new()
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
            maximum => $self->{configuration}->{publishers}->{maximum},
            maximum_simultaneous_exec => $self->{configuration}->{publishers}->{maximum_simultaneous_exec}
        )
    };

    bless $self, ref $class || $class;
}

sub register_logger_by_name {
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
        splay => 1,
        callback => sub {
            my $timer = shift;

            $timer->begin();

            local $!;

            my $collector_starting_time = time;

            my $fork_collector = sub {
                my $collector_content = shift;

                Navel::Scheduler::Core::Fork->new(
                    core => $self,
                    collector_execution_timeout => $self->{configuration}->{definition}->{collectors}->{execution_timeout},
                    collector => $collector,
                    collector_content => $collector_content,
                    ae_fork => $self->{ae_fork},
                    on_event => sub {
                        $self->{logger}->notice('AnyEvent::Fork::RPC event message for collector ' . $collector->{name} . ': ' . shift() . '.');
                    },
                    on_error => sub {
                        $self->{logger}->error('execution of collector ' . $collector->{name} . ' failed (fatal error): ' . shift() . '.');

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
                        $self->{logger}->info('AnyEvent::Fork::RPC DESTROY() called for collector ' . $collector->{name} . '.');
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
                        $self->{logger}->error(
                            $self->{logger}->stepped_log('collector ' . $collector->{name} . '.',
                                [
                                    $!
                                ]
                            )
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

    my $publisher_definition = $self->{publishers}->definition_by_name(shift);

    croak('unknown publisher') unless defined $publisher_definition;

    $self->{logger}->notice('initialize publisher ' . $publisher_definition->{name} . '.');

    push @{$self->{runtime_per_publisher}}, Navel::Broker::Publisher->new(
        definition => $publisher_definition
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

    my $generic_message = 'publisher ' . $publisher->{definition}->{name};

    my $connect_generic_message = 'connect ' . $generic_message;

    if ($publisher->{seems_connectable}) {
        unless ($publisher->is_connected()) {
            unless ($publisher->is_connecting()) {
                local $@;

                eval {
                    $publisher->connect(
                        logger => sub {
                            $self->$publisher_logger($connect_generic_message, @_);
                        }
                    );
                };

                unless ($@) {
                    $self->{logger}->notice($connect_generic_message . '.');
                } else {
                    $self->{logger}->error(
                        $self->{logger}->stepped_log($connect_generic_message . '.',
                            [
                                $@
                            ]
                        )
                    );
                }
            } else {
                $self->{logger}->warning($connect_generic_message . ': already trying to establish a connection.');
            }
        } else {
            $self->{logger}->warning($connect_generic_message . ': already connected.');
        }
    } else {
        $self->{logger}->debug($connect_generic_message . ': nothing to connect.')
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

    my $generic_message = 'publisher ' . $publisher->{definition}->{name};

    my $disconnect_generic_message = 'disconnect ' . $generic_message;

    if ($publisher->{seems_connectable}) {
        if ($publisher->is_connected() || $publisher->is_connecting()) {
            unless ($publisher->is_disconnecting()) {
                local $@;

                eval {
                    $publisher->disconnect(
                        logger => sub {
                            $self->$publisher_logger($disconnect_generic_message, @_);
                        }
                    );
                };

                unless ($@) {
                    $self->{logger}->notice($disconnect_generic_message . '.');
                } else {
                    $self->{logger}->error(
                        $self->{logger}->stepped_log($disconnect_generic_message . '.',
                            [
                                $@
                            ]
                        )
                    );
                }
            } else {
                $self->{logger}->warning($disconnect_generic_message . ': already trying to disconnect.');
            }
        } else {
            $self->{logger}->warning($disconnect_generic_message . ': already disconnected.');
        }
    } else {
        $self->{logger}->debug($generic_message . ': nothing to disconnect');
    }

    $self;
}

sub disconnect_publishers {
    my $self = shift;

    $self->disconnect_publisher_by_name($_->{name}) for @{$self->{publishers}->{definitions}};

    $self;
}

sub register_publisher_by_name {
    my $self = shift;

    my $publisher = $self->publisher_runtime_by_name(shift);

    croak('unknown publisher') unless defined $publisher;

    $self->unregister_job_by_type_and_name('publisher', $publisher->{definition}->{name});

    $self->pool_matching_job_type('publisher')->attach_timer(
        name => $publisher->{definition}->{name},
        singleton => 1,
        interval => $publisher->{definition}->{scheduling},
        splay => 1,
        callback => sub {
            my $timer = shift;

            $timer->begin();

            if ($publisher->{seems_connectable} && $publisher->{definition}->{auto_connect}) {
                $self->connect_publisher_by_name($publisher->{definition}->{name}) unless $publisher->is_connected() || $publisher->is_connecting();
            }

            my $generic_message = 'publisher ' . $publisher->{definition}->{name};

            if (my @queue = @{$publisher->{queue}}) {
                my $publish_generic_message = 'publish events for ' . $generic_message;

                unless ($publisher->{seems_connectable} && ! $publisher->is_connected()) {
                    local $@;

                    $self->{logger}->info('clear queue for publisher ' . $publisher->{definition}->{name} . '.');

                    $publisher->clear_queue();

                    eval {
                        for (@queue) {
                            my $serialize_generic_message = 'serialize datas for collection ' . $_->{collection};

                            my $serialized = eval {
                                $_->serialized_datas();
                            };

                            unless ($@) {
                                $self->{logger}->debug(
                                    $self->{logger}->stepped_log($serialize_generic_message . ': this serialized event will normally be send.',
                                        [
                                            $serialized
                                        ]
                                    )
                                );

                                $publisher->publish(
                                    event => $_,
                                    serialized_event => $serialized,
                                    logger =>  sub {
                                        $self->$publisher_logger($publish_generic_message, @_);
                                    }
                                )
                            } else {
                                $self->{logger}->error(
                                    $self->{logger}->stepped_log($serialize_generic_message . '.',
                                        [
                                            $@
                                        ]
                                    )
                                );
                            }
                        }
                    };

                    unless ($@) {
                        $self->{logger}->notice($publish_generic_message . '.');
                    } else {
                        $self->{logger}->error(
                            $self->{logger}->stepped_log($publish_generic_message . '.',
                                [
                                    $@
                                ]
                            )
                        );
                    }
                } else {
                    $self->{logger}->notice($publish_generic_message . ": publisher isn't connected.");
                }
            } else {
                $self->{logger}->info('queue for ' . $generic_message . ' is empty.');
            }

            $timer->end();
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

sub delete_publisher_and_definition_associated_by_name {
    my ($self, $name) = @_;

    croak('name must be defined') unless defined $name;

    my $finded;

    my $definition_to_delete_index = 0;

    $definition_to_delete_index++ until $finded = $self->{runtime_per_publisher}->[$definition_to_delete_index]->{definition}->{name} eq $name;

    die $self->{definition_class} . ': definition ' . $name . " does not exists\n" unless $finded;

    local $@;

    if ($self->{runtime_per_publisher}->[$definition_to_delete_index]->{seems_connectable}) {
        eval {
            $self->{runtime_per_publisher}->[$definition_to_delete_index]->disconnect(); # workaround, DESTROY with disconnect() inside does not work
        };
    }

    splice @{$self->{runtime_per_publisher}}, $definition_to_delete_index, 1;

    $self->{publishers}->delete_definition(
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

    $self->{logger}->info('add an event from collector ' . $collector_name . ' in the queue of existing publishers.');

    $_->push_in_queue(%options) for @{$self->{runtime_per_publisher}};

    $options{job}->end() if defined $options{job};

    1;
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
