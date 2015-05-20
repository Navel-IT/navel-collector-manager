# Copyright 2015 Navel-IT
# Navel Scheduler is developped by Yoann Le Garff, Nicolas Boquet and Yann Le Bras under GNU GPL v3

#-> BEGIN

#-> initialization

package Navel::Scheduler::Cron::Exec;

use strict;
use warnings;

use constant {
    FM_DEFAULT_MAX_PROCS => 10
};

use parent qw/
    Navel::Base
/;

use Scalar::Util::Numeric qw/
    isint
/;

use IO::File;

use IPC::Cmd qw/
    run
/;

use Parallel::ForkManager;

use Net::AMQP::RabbitMQ;

use Navel::RabbitMQ::Serialize::Data qw/
    to
/;

use Navel::Utils qw/
    :all
/;

our $VERSION = 0.1;

#-> methods

sub new {
    my ($class, $connector, $rabbitmq, $logger, $extra_parameters) = @_;

    if (blessed($connector) eq 'Navel::Definition::Connector' && blessed($rabbitmq) eq 'Navel::Definition::RabbitMQ::Etc::Parser' && blessed($logger) eq 'Navel::Logger') {
        my $self = {
            __datas => undef,
            __connector => $connector,
            __rabbitmq => $rabbitmq,
            __logger => $logger,
            __max_procs => isint($extra_parameters->{max_procs}) ? $extra_parameters->{max_procs} : FM_DEFAULT_MAX_PROCS
        };

        if ($connector->is_type_code()) {
            $self->{__exec} = sub {
                local $@;

                my $datas;

                if (eval "require '" . $connector->get_exec_file_path() . "'") {
                    $datas = eval {
                        connector($connector->get_properties());
                    };
                }

                if ($@) {
                    $self->{__logger}->push_to_buffer($@)->flush_buffer();

                    $self->{__logger}->clear_buffer;
                }

                return $datas;
            };
        } elsif ($connector->is_type_external()) {
            $self->{__exec} = sub {
                my ($cr, $error, $buffer, $bufferout, $buffererr) = run(
                    command => $connector->get_exec_file_path()
                );

                if ($error) {
                    $self->{__logger}->push_to_buffer(join '', @{$buffererr})->flush_buffer();

                    $self->{__logger}->clear_buffer();
                }

                return join '', @{$bufferout};
            };
        } elsif ($connector->is_type_plain_text()) {
            $self->{__exec} = sub {
                my $datas;

                my $fh = IO::File->new();

                $fh->binmode(':encoding(UTF-8)');

                if ($fh->open('< ' . $connector->get_exec_file_path())) {
                    local $/;

                    $datas = <$fh>;

                    $fh->close();
                } else {
                    $self->{__logger}->push_to_buffer($!)->flush_buffer();

                    $self->{__logger}->clear_buffer();
                }

                return $datas;
            };
        }

        $class = ref $class || $class;

        return bless $self, $class;
    }

    croak('Object(s) invalid(s).');
}

sub exec {
    my $self = shift;

    return $self->set_datas($self->get_exec()->());
}

sub push {
    my $self = shift;

    my $serialize = to(
        $self->get_connector(),
        $self->get_datas()
    );

    if ($serialize->[0]) {
        my $fm = Parallel::ForkManager->new($self->get_max_procs());

        for my $rabbitmq (@{$self->get_rabbitmq()->get_definitions()}) {
            $fm->start() && next;

            my $pusher = Net::AMQP::RabbitMQ->new();

            my $channel_id = 1;

            my %naming_conventions = (
                exchange => 'navel-scheduler.E.direct.events',
                queue => 'navel-scheduler.Q.events',
                binding_key => 'navel-scheduler.collection.' . $self->get_connector()->get_collection()
            );

            my %options = (
                user => $rabbitmq->get_user(),
                password => $rabbitmq->get_password(),
                port => $rabbitmq->get_port(),
                vhost => $rabbitmq->get_vhost()
            );

            $options{timeout} = $rabbitmq->get_timeout() if ($rabbitmq->get_timeout());

            eval {
                $pusher->connect($rabbitmq->get_host(), \%options);

                $pusher->channel_open($channel_id); # $pusher->get_channel_max()

                $pusher->exchange_declare($channel_id, $naming_conventions{exchange},
                    {
                        durable => 1
                    }
                );

                for (@{$rabbitmq->get_queues_suffix()}) {
                    my $queue_name = $naming_conventions{queue} . '.' . $_;

                    $pusher->queue_declare($channel_id, $queue_name,
                        {
                            durable => 1
                        }
                    );

                    $pusher->queue_bind($channel_id, $queue_name, $naming_conventions{exchange}, $naming_conventions{binding_key});

                }

                $pusher->publish($channel_id, $naming_conventions{binding_key}, $serialize->[1],
                    {
                        exchange => $naming_conventions{exchange}
                    }
                );

                $pusher->disconnect();
            };

            if ($@) {
                $self->get_logger()->push_to_buffer($@)->flush_buffer();

                $self->get_logger()->clear_buffer();
            }

            $fm->finish();
        }

        return $fm->wait_all_children();
    }

    return 0;
}

sub set_datas {
    my ($self, $datas) = @_;

    $self->{__datas} = $datas;

    return $self;
}

sub get_datas {
    return shift->{__datas};
}

sub get_connector {
    return shift->{__connector};
}

sub get_rabbitmq {
    return shift->{__rabbitmq};
}

sub get_logger {
    return shift->{__logger};
}

sub get_max_procs {
    return shift->{__max_procs};
}

sub get_exec {
    return shift->{__exec};
}

# sub AUTOLOAD {}

# sub DESTROY {}

1;

#-> END

__END__

=pod

=head1 NAME

Navel::Scheduler::Cron::Exec

=head1 AUTHOR

Yoann Le Garff, Nicolas Boquet and Yann Le Bras

=head1 LICENSE

GNU GPL v3

=cut