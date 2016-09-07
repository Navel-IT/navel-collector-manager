# Copyright (C) 2015 Yoann Le Garff, Nicolas Boquet and Yann Le Bras
# navel-scheduler is licensed under the Apache License, Version 2.0

#-> BEGIN

#-> initialization

package Navel::Scheduler::Core 0.1;

use Navel::Base;

use EV;

use parent 'Navel::Base::Daemon::Core';

use AnyEvent::Fork;

use Navel::Logger::Message;
use Navel::Definition::Collector::Parser;
use Navel::Definition::Publisher::Parser;
use Navel::AnyEvent::Pool;
use Navel::Scheduler::Core::Collector::Fork;
use Navel::Broker::Client::Fork;
use Navel::Event;
use Navel::Utils qw/
    isint
    croak
/;

#-> methods

sub new {
    my ($class, %options) = @_;

    my $self = $class->SUPER::new(%options);

    $self->{collectors} = Navel::Definition::Collector::Parser->new(
        maximum => $self->{meta}->{definition}->{collectors}->{maximum}
    )->read(
        file_path => $self->{meta}->{definition}->{collectors}->{definitions_from_file}
    )->make();

    $self->{runtime_per_collector} = {};

    $self->{publishers} = Navel::Definition::Publisher::Parser->new(
        maximum => $self->{meta}->{definition}->{publishers}->{maximum}
    )->read(
        file_path => $self->{meta}->{definition}->{publishers}->{definitions_from_file}
    )->make();

    $self->{runtime_per_publisher} = {};

    $self->{job_types} = {
        %{$self->{job_types}},
        %{
            {
                collector => Navel::AnyEvent::Pool->new(
                    logger => $options{logger},
                    maximum => $self->{meta}->{definition}->{collectors}->{maximum}
                ),
                publisher => Navel::AnyEvent::Pool->new(
                    logger => $options{logger},
                    maximum => $self->{meta}->{definition}->{publishers}->{maximum}
                )
            }
        }
    };

    $self->{ae_fork} = AnyEvent::Fork->new();

    bless $self, ref $class || $class;
}

sub init_collector_by_name {
    my $self = shift;

    my $collector = $self->{collectors}->definition_by_name(shift);

    die "unknown collector definition\n" unless defined $collector;

    my $collector_pool = $self->pool_matching_job_type('collector');

    $self->{logger}->notice($collector->full_name() . ': initialization.');

    my $on_event_error_message_prefix = $collector->full_name() . ': incorrect behavior/declaration.';

    $self->{runtime_per_collector}->{$collector->{name}} = Navel::Scheduler::Core::Collector::Fork->new(
        core => $self,
        definition => $collector,
        on_event => sub {
            local $@;

            for (@_) {
                if (ref eq 'ARRAY') {
                    if (isint($_->[0])) {
                        if ($_->[0] == Navel::Scheduler::Core::Collector::Fork::EVENT_EVENT) {
                            eval {
                                $self->goto_collector_next_stage(
                                    collector => $collector,
                                    time => time,
                                    data => $_->[1]
                                );
                            };
                        } elsif ($_->[0] == Navel::Scheduler::Core::Collector::Fork::EVENT_LOG) {
                            eval {
                                $self->{logger}->push_in_queue(
                                    severity => $_->[1],
                                    text => $collector->full_name() . ': ' . $_->[2]
                                ) if defined $_->[2];
                            };
                        } else {
                            $self->{logger}->err(
                                Navel::Logger::Message->stepped_message($on_event_error_message_prefix,
                                    [
                                        'unknown event type.'
                                    ]
                                )
                            );
                        }

                        $self->{logger}->err(
                            Navel::Logger::Message->stepped_message($on_event_error_message_prefix,
                                [
                                    $@
                                ]
                            )
                        ) if $@;
                    } else {
                        $self->{logger}->err(
                            Navel::Logger::Message->stepped_message($on_event_error_message_prefix,
                                [
                                    'event type must be an integer.'
                                ]
                            )
                        );
                    }
                } else {
                    $self->{logger}->err(
                        Navel::Logger::Message->stepped_message($on_event_error_message_prefix,
                            [
                                'event must be a ARRAY reference.'
                            ]
                        )
                    );
                }
            }
        },
        on_error => sub {
            $self->{logger}->warning($collector->full_name() . ': execution stopped (fatal): ' . shift . '.');

            $self->goto_collector_next_stage(
                job => $self->job_by_type_and_name('collector', $collector->{name}),
                collector => $collector,
                status => 'itl',
                time => time
            );
        },
        on_destroy => sub {
            $self->{logger}->info($collector->full_name() . ': destroyed.');
        }
    );

    $self;
}

sub init_collectors {
    my $self = shift;

    $self->init_collector_by_name($_->{name}) for @{$self->{collectors}->{definitions}};

    $self;
}

sub register_collector_by_name {
    my ($self, $name) = @_;

    croak('name must be defined') unless defined $name;

    my $collector = $self->{runtime_per_collector}->{$name};

    die "unknown collector runtime\n" unless defined $collector;

    my $on_catch = sub {
        $self->{logger}->warning(
            Navel::Logger::Message->stepped_message($collector->{definition}->full_name() . ': cannot propagate order to the runtime.',
                [
                    shift
                ]
            )
        );
    };

    my %timer_options = (
        name => $collector->{definition}->{name},
        singleton => 1,
        interval => $collector->{definition}->{scheduling},
        splay => 1,
        callback => sub {
            my $timer = shift->begin();

            $self->{runtime_per_collector}->{$collector->{definition}->{name}}->rpc()->then(
                sub {
                    $self->{logger}->debug($collector->{definition}->full_name() . ': ' . $timer->full_name() . ': execution successfully propagated to the runtime.');
                }
            )->catch($on_catch)->finally(
                sub {
                    $timer->end();
                }
            );
        }
    );

    if ($collector->{definition}->{async}) {
        $timer_options{on_enable} = sub {
            my $timer = shift;

            $self->{runtime_per_collector}->{$collector->{definition}->{name}}->rpc('enable')->then(
                sub {
                    $self->{logger}->debug($collector->{definition}->full_name() . ': ' . $timer->full_name() . ' activation successfully propagated to the runtime.');
                }
            )->catch($on_catch);
        };

        $timer_options{on_disable} = sub {
            my $timer = shift;

            $self->{runtime_per_collector}->{$collector->{definition}->{name}}->rpc('disable')->then(
                sub {
                    $self->{logger}->debug($collector->{definition}->full_name() . ': ' . $timer->full_name() . ' deactivation successfully propagated to the runtime.');
                }
            )->catch($on_catch);
        };
    }

    $self->unregister_job_by_type_and_name('collector', $collector->{definition}->{name})->pool_matching_job_type('collector')->attach_timer(%timer_options);

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

    $self->unregister_job_by_type_and_name('collector', $collector->{name})->{collectors}->delete_definition(
        definition_name => $collector->{name}
    );

    delete $self->{runtime_per_collector}->{$collector->{name}};

    $self;
}

sub delete_collectors {
    my $self = shift;

    $self->delete_collector_and_definition_associated_by_name($_->{name}) for @{$self->{collectors}->{definitions}};

    $self;
}

sub init_publisher_by_name {
    my $self = shift;

    my $publisher = $self->{publishers}->definition_by_name(shift);

    die "unknown publisher definition\n" unless defined $publisher;

    $self->{logger}->notice($publisher->full_name() . ': initialization.');

    my $on_event_error_message_prefix = $publisher->full_name() . ': incorrect behavior/declaration.';

    $self->{runtime_per_publisher}->{$publisher->{name}} = Navel::Broker::Client::Fork->new(
        logger => $self->{logger},
        meta_configuration => $self->{meta}->{definition}->{publishers},
        definition => $publisher,
        ae_fork => $self->{ae_fork},
        on_event => sub {
            local $@;

            for (@_) {
                if (ref eq 'ARRAY') {
                    eval {
                        $self->{logger}->push_in_queue(
                            severity => $_->[0],
                            text => $publisher->full_name() . ': ' . $_->[1]
                        ) if defined $_->[1];
                    };

                    $self->{logger}->err(
                        Navel::Logger::Message->stepped_message($on_event_error_message_prefix,
                            [
                                $@
                            ]
                        )
                    ) if $@;
                } else {
                    $self->{logger}->err(
                        Navel::Logger::Message->stepped_message($on_event_error_message_prefix,
                            [
                                'event must be a ARRAY reference.'
                            ]
                        )
                    );
                }
            }
        },
        on_error => sub {
            $self->{logger}->warning($publisher->full_name() . ': execution stopped (fatal): ' . shift . '.');
        },
        on_destroy => sub {
            $self->{logger}->info($publisher->full_name() . ': destroyed.');
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

    my $connect_generic_message = $publisher->{definition}->full_name() . ': connecting.';

    if ($publisher->{definition}->{connectable}) {
        $publisher->rpc(
            action => 'is_connected'
        )->then(
            sub {
                shift ? die 'already connected.' : $publisher->rpc(
                    action => 'is_connecting'
                );
            }
        )->then(
            sub {
                shift ? die 'already trying to establish a connection.' : $publisher->rpc(
                    action => 'connect'
                );
            }
        )->catch(
            sub {
                $self->{logger}->warning(
                    Navel::Logger::Message->stepped_message($connect_generic_message,
                        [
                            shift
                        ]
                    )
                );
            }
        );
    } else {
        $self->{logger}->debug(
            Navel::Logger::Message->stepped_message($connect_generic_message,
                [
                    'nothing to connect.'
                ]
            )
        );
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

    my $disconnect_generic_message = $publisher->{definition}->full_name() . ': disconnecting.';

    if ($publisher->{definition}->{connectable}) {
        $publisher->rpc(
            action => 'is_disconnected'
        )->then(
            sub {
                shift ? die 'already disconnected.' : $publisher->rpc(
                    action => 'is_disconnecting'
                );
            }
        )->then(
            sub {
                shift ? die 'already trying to disconnect.' : $publisher->rpc(
                    action => 'disconnect'
                );
            }
        )->catch(
            sub {
                $self->{logger}->warning(
                    Navel::Logger::Message->stepped_message($disconnect_generic_message,
                        [
                            shift
                        ]
                    )
                );
            }
        );
    } else {
        $self->{logger}->debug(
            Navel::Logger::Message->stepped_message($disconnect_generic_message,
                [
                    'nothing to disconnect.'
                ]
            )
        );
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

    $self->{logger}->debug($options{publisher}->{definition}->full_name() . ': trying to publicate the events.');

    $options{publisher}->rpc(
        action => 'publish',
        options => [
            $options{publisher}->{queue}
        ]
    )->then(
        sub {
            $self->{logger}->debug($options{publisher}->{definition}->full_name() . ': clear queue.');

            $options{publisher}->clear_queue();
        }
    )->catch(
        sub {
            $self->{logger}->warning($options{publisher}->{definition}->full_name() . ': ' . shift);
        }
    )->finally(
        sub {
            $options{job}->end();
        }
    );

    $self;
};

sub register_publisher_by_name {
    my ($self, $name) = @_;

    croak('name must be defined') unless defined $name;

    my $publisher = $self->{runtime_per_publisher}->{$name};

    die "unknown publisher runtime\n" unless defined $publisher;

    $self->unregister_job_by_type_and_name('publisher', $publisher->{definition}->{name})->pool_matching_job_type('publisher')->attach_timer(
        name => $publisher->{definition}->{name},
        singleton => 1,
        interval => $publisher->{definition}->{scheduling},
        splay => 1,
        callback => sub {
            my $timer = shift->begin();

            my $on_catch = sub {
                $self->{logger}->warning($publisher->{definition}->full_name() . ': ' . shift);
            };

            if ($publisher->{definition}->{connectable} && $publisher->{definition}->{auto_connect}) {
                $publisher->rpc(
                    action => 'is_connected'
                )->then(
                    sub {
                        $publisher->rpc(
                            action => 'is_connecting'
                        ) unless shift;
                    }
                )->then(
                    sub {
                        $self->connect_publisher_by_name($publisher->{definition}->{name}) unless shift;
                    }
                )->catch($on_catch);
            }

            if (@{$publisher->{queue}}) {
                if ($publisher->{definition}->{connectable}) {
                    $publisher->rpc(
                        action => 'is_connected'
                    )->then(
                        sub {
                            if (shift) {
                                $self->$register_publisher_by_name_common_workflow(
                                    job => $timer,
                                    publisher => $publisher
                                );
                            } else {
                                $self->{logger}->notice($publisher->{definition}->full_name() . ": isn't connected.");

                                $timer->end();
                            }
                        }
                    )->catch($on_catch);
                } else {
                    $self->$register_publisher_by_name_common_workflow(
                        job => $timer,
                        publisher => $publisher
                    );
                }
            } else {
                $self->{logger}->debug($publisher->{definition}->full_name() . ': queue is empty.');

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

    $self->unregister_job_by_type_and_name('publisher', $publisher->{name})->{publishers}->delete_definition(
        definition_name => $publisher->{name}
    );

    delete $self->{runtime_per_publisher}->{$publisher->{name}};

    $self;
}

sub delete_publishers {
    my $self = shift;

    $self->delete_publisher_and_definition_associated_by_name($_->{name}) for @{$self->{publishers}->{definitions}};

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
    my $self = shift;

    my $job = $self->job_by_type_and_name(@_);

    $job->DESTROY() if defined $job;

    $self;
}

sub goto_collector_next_stage {
    my ($self, %options) = @_;

    my $job = delete $options{job};

    if (%options) {
        my $event = Navel::Event->new(%options);

        for (values %{$self->{runtime_per_publisher}}) {
            $self->{logger}->info($_->{definition}->full_name() . ': add an event from collector ' . $options{collector}->{name} . '.') if $_->push_in_queue($event);
        }
    }

    $job->end() if defined $job;

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
