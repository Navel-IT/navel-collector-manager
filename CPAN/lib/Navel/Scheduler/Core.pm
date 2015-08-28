# Copyright 2015 Navel-IT
# Navel Scheduler is developed by Yoann Le Garff, Nicolas Boquet and Yann Le Bras under GNU GPL v3

#-> BEGIN

#-> initialization

package Navel::Scheduler::Core;

use strict;
use warnings;

use parent 'Navel::Base';

use constant {
    CONNECTOR_JOB_PREFIX => 'connector_',
    PUBLISHER_JOB_PREFIX => 'publisher_',
    LOGGER_JOB_PREFIX => 'logger_'
};

use Carp 'croak';

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
        connectors => $options{connectors},
        rabbitmq => $options{rabbitmq},
        publishers => [],
        logger => $options{logger},
        cron => AnyEvent::DateTime::Cron->new(
            quartz => 1
        ),
        jobs => {
            enabled => {},
            connectors => {
                locks => {},
                running => 0
            }
        }
    }, ref $class || $class;
}

sub register_the_logger {
    my $self = shift;

    my $job_name = LOGGER_JOB_PREFIX . '0';

    $self->{jobs}->{enabled}->{$job_name} = 1;

    $self->{cron}->add(
        '*/2 * * * * ?',
        name => $job_name,
        single => 1,
        sub {
            $self->{logger}->flush_queue(
                clear_queue => 1
            ) if $self->{jobs}->{enabled}->{$job_name};
        }
    );

    $self;
}

sub register_connector_by_name {
    my $self = shift;

    my $connector = $self->{connectors}->definition_by_name(shift);

    my $job_name = CONNECTOR_JOB_PREFIX . $connector->{name};

    $self->{jobs}->{enabled}->{$job_name} = 1;
    $self->{jobs}->{connectors}->{locks}->{$connector->{name}} = 0;

    $self->{cron}->add(
        $connector->{scheduling},
        name => $job_name,
        single => 1,
        sub {
            local ($@, $!);

            if ( ! $self->{configuration}->{definition}->{connectors}->{maximum_simultaneous_exec} || $self->{configuration}->{definition}->{connectors}->{maximum_simultaneous_exec} > $self->{jobs}->{connectors}->{running}) {
                if ($self->{jobs}->{enabled}->{$job_name}) {
                    unless ($self->{jobs}->{connectors}->{locks}->{$connector->{name}}) {
                        $self->{jobs}->{connectors}->{running}++;

                        $self->{jobs}->{connectors}->{locks}->{$connector->{name}} = $connector->{singleton};

                        aio_load($connector->exec_file_path(),
                            sub {
                                my ($connector_content) = @_;

                                if ($connector_content) {
                                    if ($connector->is_type_code()) {
                                        Navel::Scheduler::Core::Fork->new(
                                            core => $self,
                                            connector_execution_timeout => $self->{configuration}->{definition}->{connectors}->{execution_timeout},
                                            connector => $connector,
                                            connector_content => $connector_content
                                        )->when_done(
                                            callback => sub {
                                                $self->a_connector_stop(
                                                    connector => $connector,
                                                    event_definition => {
                                                        connector => $connector,
                                                        datas => shift
                                                    }
                                                );
                                            }
                                        );
                                    } else {
                                        $self->a_connector_stop(
                                            connector => $connector,
                                            event_definition => {
                                                connector => $connector,
                                                datas => $connector_content
                                            }
                                        );
                                    }
                                } else {
                                    $self->{logger}->bad(
                                        message => 'Connector ' . $connector->{name} . ': ' . $! . '.',
                                        severity => 'err'
                                    );

                                    $self->a_connector_stop(
                                        connector => $connector,
                                        event_definition => {
                                            connector => $connector
                                        },
                                        status_method => 'set_ko_no_source'
                                    );
                                }
                            }
                        );
                    } else {
                        $self->{logger}->push_in_queue(
                            message => 'Connector ' . $connector->{name} . ' is already running.',
                            severity => 'debug'
                        );
                    }
                } else {
                    $self->{logger}->push_in_queue(
                        message => 'Job ' . $job_name . ' is disabled.',
                        severity => 'debug'
                    );
                }
            } else {
                $self->{logger}->push_in_queue(
                    message => 'Too much connectors are running (maximum of ' . $self->{configuration}->{definition}->{connectors}->{maximum_simultaneous_exec} . ').',
                    severity => 'debug'
                );
            }
        }
    );

    $self;
}

sub register_connectors {
    my $self = shift;

    $self->register_connector_by_name($_->{name}) for @{$self->{connectors}->{definitions}};

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

                    $self->{logger}->good(
                        message => $publisher_connect_generic_message . ' successfuly connected.',
                        severity => 'notice'
                    );

                    $amqp_connection->open_channel(
                        on_success => sub {
                            $self->{logger}->good(
                                message => $publisher_generic_message . ': channel opened.',
                                severity => 'notice'
                            );
                        },
                        on_failure => sub {
                            $self->{logger}->bad(
                                message => $publisher_generic_message . ': channel failure ... ' . join(' ', @_) . '.',
                                severity => 'notice'
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
                    $self->{logger}->bad(
                        message => $publisher_connect_generic_message . ': failure ... ' . join(' ', @_) . '.',
                        severity => 'warn'
                    );
                },
                on_read_failure => sub {
                    $self->{logger}->bad(
                        message => $publisher_generic_message . ': read failure ... ' . join(' ', @_) . '.',
                        severity => 'warn'
                    );
                },
                on_return => sub {
                    $self->{logger}->bad(
                        message => $publisher_generic_message . ': unable to deliver frame.',
                        severity => 'warn'
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
            $self->{logger}->bad(
                message => $publisher_connect_generic_message . ': ' . $@ . '.',
                severity => 'warn'
            );
        }
    } else {
        $self->{logger}->bad(
            message => $publisher_connect_generic_message . ': seem already connected.',
            severity => 'notice'
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
                                severity => 'notice'
                            );

                            $publisher->clear_queue();

                            eval {
                                for my $event (@queue) {
                                    my $serialize_generic_message = 'Serialize datas for collection ' . $event->{collection};

                                    my $serialized = eval {
                                        $event->serialized_datas();
                                    };

                                    unless ($@) {
                                        $self->{logger}->good(
                                            message => $serialize_generic_message . '.',
                                            severity => 'debug'
                                        );

                                        my $routing_key = $event->routing_key();

                                        $self->{logger}->push_in_queue(
                                            message => $publish_generic_message . ': sending one event with routing key ' . $routing_key . ' to exchange ' . $publisher->{definition}->{exchange} . '.',
                                            severity => 'debug'
                                        );

                                        $channels[0]->publish(
                                            exchange => $publisher->{definition}->{exchange},
                                            routing_key => $event->routing_key(),
                                            header => {
                                                delivery_mode => $publisher->{definition}->{delivery_mode}
                                            },
                                            body => $serialized
                                        );
                                    } else {
                                        $self->{logger}->bad(
                                            message => $serialize_generic_message . ' failed: ' . $@ . '.' ,
                                            severity => 'warn'
                                        );
                                    }
                                }
                            };

                            if ($@) {
                                $self->{logger}->bad(
                                    message => $publish_generic_message . ': ' . $@ . '.',
                                    severity => 'warn'
                                );
                            } else {
                                $self->{logger}->good(
                                    message => $publish_generic_message . '.',
                                    severity => 'notice'
                                );
                            }
                        } else {
                            $self->{logger}->bad(
                                message => $publish_generic_message . ': publisher has no channel opened.',
                                severity => 'warn'
                            );
                        }
                    } else {
                        $self->{logger}->push_in_queue(
                            message => $publish_generic_message . ': publisher is not connected.',
                            severity => 'notice'
                        );
                    }
                } else {
                    $self->{logger}->push_in_queue(
                        message => 'Buffer for publisher ' . $publisher->{definition}->{name} . ' is empty.',
                        severity => 'info'
                    );
                }
            } else {
                $self->{logger}->push_in_queue(
                    message => 'Job ' . $job_name . ' is disabled.',
                    severity => 'debug'
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
            $self->{logger}->good(
                message => $disconnect_generic_message . '.',
                severity => 'notice'
            );
        } else {
            $self->{logger}->bad(
                message => $disconnect_generic_message . ': ' . $@ . '.',
                severity => 'warn'
            );
        }
    } else {
        $self->{logger}->bad(
            message => $disconnect_generic_message . ': seem already disconnected.',
            severity => 'notice'
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

    my $definition_to_delete_index = 0;

    my $finded;

    $definition_to_delete_index++ until $finded = $self->{publishers}->[$definition_to_delete_index]->{definition}->{name} eq $name;

    croak($self->{definition_class} . ': definition ' . $name . ' does not exists') unless $finded;

    eval {
        $self->{publishers}->[$definition_to_delete_index]->disconnect(); # work around, DESTROY with disconnect() inside does not work
    };

    splice @{$self->{publishers}}, $definition_to_delete_index, 1;

    $self->{rabbitmq}->delete_definition($name);
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

sub a_connector_stop {
    my ($self, %options) = @_;

    my $connector = delete $options{connector};

    $self->{logger}->push_in_queue(
        message => 'Add an event from connector ' . $connector->{name} . ' in the queue of existing publishers.',
        severity => 'info'
    );

    $_->push_in_queue(%options) for @{$self->{publishers}};

    $self->{jobs}->{connectors}->{locks}->{$connector->{name}} = 0;

    $self->{jobs}->{connectors}->{running}--;

    1;
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

