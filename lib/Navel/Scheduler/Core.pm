# Copyright (C) 2015-2016 Yoann Le Garff, Nicolas Boquet and Yann Le Bras
# navel-scheduler is licensed under the Apache License, Version 2.0

#-> BEGIN

#-> initialization

package Navel::Scheduler::Core 0.1;

use Navel::Base;

use EV;

use parent 'Navel::Base::Daemon::Core';

use AnyEvent::Fork;

use Promises 'collect';

use Navel::Logger::Message;
use Navel::Definition::Collector::Parser;
use Navel::AnyEvent::Pool;
use Navel::Scheduler::Core::Collector::Fork;
use Navel::Utils 'croak';

#-> methods

sub new {
    my ($class, %options) = @_;

    my $self = $class->SUPER::new(%options);

    $self->{collectors} = Navel::Definition::Collector::Parser->new(
        maximum => $self->{meta}->{definition}->{collectors}->{maximum}
    )->read(
        file_path => $self->{meta}->{definition}->{collectors}->{definitions_from_file}
    )->make;

    $self->{worker_per_collector} = {};

    $self->{job_types} = {
        %{$self->{job_types}},
        %{
            {
                collector => Navel::AnyEvent::Pool->new(
                    logger => $options{logger},
                    maximum => $self->{meta}->{definition}->{collectors}->{maximum}
                )
            }
        }
    };

    $self->{ae_fork} = AnyEvent::Fork->new;

    bless $self, ref $class || $class;
}

sub init_collector_by_name {
    my $self = shift;

    my $collector = $self->{collectors}->definition_by_name(shift);

    die "unknown collector definition\n" unless defined $collector;

    $self->{logger}->notice($collector->full_name . ': initialization.');

    my $on_event_error_message_prefix = $collector->full_name . ': incorrect behavior/declaration.';

    $self->{worker_per_collector}->{$collector->{name}} = Navel::Scheduler::Core::Collector::Fork->new(
        core => $self,
        definition => $collector,
        on_event => sub {
            local $@;

            for (@_) {
                if (ref eq 'ARRAY') {
                    eval {
                        $self->{logger}->enqueue(
                            severity => $_->[0],
                            text => $collector->full_name . ': ' . $_->[1]
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
            $self->{logger}->warning($collector->full_name . ': execution stopped (fatal): ' . shift . '.');
        },
        on_destroy => sub {
            $self->{logger}->info($collector->full_name . ': destroyed.');
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

    my $collector = $self->{worker_per_collector}->{$name};

    die "unknown collector worker\n" unless defined $collector;

    my $on_catch = sub {
        $self->{logger}->warning(
            Navel::Logger::Message->stepped_message($collector->{definition}->full_name . ': chain of action cannot be completed.', \@_)
        );
    };

    $self->unregister_job_by_type_and_name('collector', $collector->{definition}->{name})->pool_matching_job_type('collector')->attach_timer(
        name => $collector->{definition}->{name},
        singleton => 1,
        splay => 1,
        interval => 1,
        callback => sub {
            my $timer = shift->begin;

            $collector->rpc(
                $collector->{definition}->{publisher_backend},
                'is_connectable'
            )->then(
                sub {
                    if (shift) {
                        $self->{logger}->debug($collector->{definition}->full_name . ': ' . $timer->full_name . ': the associated publisher is apparently connectable.');

                        collect(
                            $collector->rpc($collector->{definition}->{publisher_backend}, 'is_connected'),
                            $collector->rpc($collector->{definition}->{publisher_backend}, 'is_connecting')
                        );
                    } else {
                        (
                            [
                                1
                            ],
                            [
                                0
                            ]
                        );
                    }
                }
            )->then(
                sub {
                    if (shift->[0]) {
                        $self->{logger}->debug($collector->{definition}->full_name . ': ' . $timer->full_name . ': starting publication.');

                        $collector->rpc($collector->{definition}->{publisher_backend}, 'publish');
                    } else {
                        if (shift->[0]) {
                            die "connecting is in progress, cannot continue\n";
                        } else {
                            $self->{logger}->debug($collector->{definition}->full_name . ': ' . $timer->full_name . ': starting connection.');

                            $collector->rpc($collector->{definition}->{publisher_backend}, 'connect');
                        }
                    }
                }
            )->then(
                sub {
                    $self->{logger}->notice($collector->{definition}->full_name . ': ' . $timer->full_name . ': chain of action successfully completed.');
                }
            )->catch($on_catch)->finally(
                sub {
                    $timer->end;
                }
            );
        },
        on_enable => sub {
            my $timer = shift;

            collect(
                $collector->rpc($collector->{definition}->{backend}, 'enable'),
                $collector->rpc($collector->{definition}->{publisher_backend}, 'enable')
            )->then(
                sub {
                    $self->{logger}->notice($collector->{definition}->full_name . ': ' . $timer->full_name . ': chain of activation successfully completed.');
                }
            )->catch($on_catch);
        },
        on_disable => sub {
            my $timer = shift;

            collect(
                $collector->rpc($collector->{definition}->{backend}, 'disable'),
                $collector->rpc($collector->{definition}->{publisher_backend}, 'disable')
            )->then(
                sub {
                    $self->{logger}->notice($collector->{definition}->full_name . ': ' . $timer->full_name . ': chain of deactivation successfully completed.');
                }
            )->catch($on_catch);
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

    die "unknown collector worker\n" unless defined $collector;

    $self->unregister_job_by_type_and_name('collector', $collector->{name})->{collectors}->delete_definition(
        definition_name => $collector->{name}
    );

    delete $self->{worker_per_collector}->{$collector->{name}};

    $self;
}

sub delete_collectors {
    my $self = shift;

    $self->delete_collector_and_definition_associated_by_name($_->{name}) for @{$self->{collectors}->{definitions}};

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

Copyright (C) 2015-2016 Yoann Le Garff, Nicolas Boquet and Yann Le Bras

=head1 LICENSE

navel-scheduler is licensed under the Apache License, Version 2.0

=cut
