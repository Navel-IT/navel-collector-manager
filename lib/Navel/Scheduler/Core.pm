# Copyright (C) 2015-2016 Yoann Le Garff, Nicolas Boquet and Yann Le Bras
# navel-scheduler is licensed under the Apache License, Version 2.0

#-> BEGIN

#-> initialization

package Navel::Scheduler::Core 0.1;

use Navel::Base;

use parent 'Navel::Base::WorkerManager::Core';

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

    $self->{definitions} = Navel::Definition::Collector::Parser->new(
        maximum => $self->{meta}->{definition}->{collectors}->{maximum}
    )->read(
        file_path => $self->{meta}->{definition}->{collectors}->{definitions_from_file}
    )->make;

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

    bless $self, ref $class || $class;
}

sub init_worker_by_name {
    my $self = shift;

    my $definition = $self->{definitions}->definition_by_name(shift);

    die "unknown definition\n" unless defined $definition;

    $self->{logger}->notice($definition->full_name . ': initialization.');

    my $on_event_error_message_prefix = $definition->full_name . ': incorrect behavior/declaration.';

    $self->{worker_per_definition}->{$definition->{name}} = Navel::Scheduler::Core::Collector::Fork->new(
        core => $self,
        definition => $definition,
        on_event => sub {
            local $@;

            for (@_) {
                if (ref eq 'ARRAY') {
                    eval {
                        $self->{logger}->enqueue(
                            severity => $_->[0],
                            text => $definition->full_name . ': ' . $_->[1]
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
            $self->{logger}->warning($definition->full_name . ': execution stopped (fatal): ' . shift . '.');
        },
        on_destroy => sub {
            $self->{logger}->info($definition->full_name . ': destroyed.');
        }
    );

    $self;
}

sub register_worker_by_name {
    my ($self, $name) = @_;

    croak('name must be defined') unless defined $name;

    my $worker = $self->{worker_per_definition}->{$name};

    die "unknown worker\n" unless defined $worker;

    my $on_catch = sub {
        $self->{logger}->warning(
            Navel::Logger::Message->stepped_message($worker->{definition}->full_name . ': chain of action cannot be completed.', \@_)
        );
    };

    $self->unregister_job_by_type_and_name('collector', $worker->{definition}->{name})->pool_matching_job_type('collector')->attach_timer(
        name => $worker->{definition}->{name},
        singleton => 1,
        splay => 1,
        interval => 1,
        callback => sub {
            my $timer = shift->begin;

            $worker->rpc(
                $worker->{definition}->{publisher_backend},
                'is_connectable'
            )->then(
                sub {
                    if (shift) {
                        $self->{logger}->debug($worker->{definition}->full_name . ': ' . $timer->full_name . ': the associated publisher is apparently connectable.');

                        collect(
                            $worker->rpc($worker->{definition}->{publisher_backend}, 'is_connected'),
                            $worker->rpc($worker->{definition}->{publisher_backend}, 'is_connecting')
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
                        $self->{logger}->debug($worker->{definition}->full_name . ': ' . $timer->full_name . ': starting publication.');

                        $worker->rpc($worker->{definition}->{publisher_backend}, 'publish');
                    } else {
                        if (shift->[0]) {
                            die "connecting is in progress, cannot continue\n";
                        } else {
                            $self->{logger}->debug($worker->{definition}->full_name . ': ' . $timer->full_name . ': starting connection.');

                            $worker->rpc($worker->{definition}->{publisher_backend}, 'connect');
                        }
                    }
                }
            )->then(
                sub {
                    $self->{logger}->notice($worker->{definition}->full_name . ': ' . $timer->full_name . ': chain of action successfully completed.');
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
                $worker->rpc($worker->{definition}->{backend}, 'enable'),
                $worker->rpc($worker->{definition}->{publisher_backend}, 'enable')
            )->then(
                sub {
                    $self->{logger}->notice($worker->{definition}->full_name . ': ' . $timer->full_name . ': chain of activation successfully completed.');
                }
            )->catch($on_catch);
        },
        on_disable => sub {
            my $timer = shift;

            collect(
                $worker->rpc($worker->{definition}->{backend}, 'disable'),
                $worker->rpc($worker->{definition}->{publisher_backend}, 'disable')
            )->then(
                sub {
                    $self->{logger}->notice($worker->{definition}->full_name . ': ' . $timer->full_name . ': chain of deactivation successfully completed.');
                }
            )->catch($on_catch);
        }
    );

    $self;
}

sub delete_worker_and_definition_associated_by_name {
    my $self = shift;

    $self->SUPER::delete_worker_and_definition_associated_by_name('collector', @_);

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
