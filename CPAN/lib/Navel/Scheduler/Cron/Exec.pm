# Copyright 2015 Navel-IT
# Navel Scheduler is developped by Yoann Le Garff, Nicolas Boquet and Yann Le Bras under GNU GPL v3

#-> BEGIN

#-> initialization

package Navel::Scheduler::Cron::Exec;

use 5.10.1;

use strict;
use warnings;

use parent qw/
    Navel::Base
/;

use Scalar::Util::Numeric qw/
    isint
/;

use AnyEvent::Fork;

use AnyEvent::Fork::RPC;

use File::Slurp;

use IPC::Cmd qw/
    run
/;

use Navel::RabbitMQ::Serialize::Data qw/
    to
/;

use Navel::Utils qw/
    :all
/;

our $VERSION = 0.1;

#-> methods

sub new {
    my ($class, $connector, $rabbitmq, $logger) = @_;

    if (blessed($connector) eq 'Navel::Definition::Connector' && blessed($rabbitmq) eq 'Navel::Definition::RabbitMQ::Etc::Parser' && blessed($logger) eq 'Navel::Logger') {
        my $self = {
            __datas => undef,
            __connector => $connector,
            __rabbitmq => $rabbitmq,
            __logger => $logger
        };

        my $connector_generic_failed_message = 'Execution of connector ' . $connector->get_name() . ' failed';

        if ($connector->is_type_code()) {
            $self->{__exec} = sub {
                my $self = shift;

                my $perl_code_content = eval {
                    read_file($self->get_connector()->get_exec_file_path());
                };

                my $proc = AnyEvent::Fork->new_exec()->require(
                    'strict',
                    'warnings'
                )->eval(
                    $perl_code_content
                );
                
                my $rpc = $proc->AnyEvent::Fork::RPC::run(
                    'connector',
                    on_event => sub {
                        my $event_type = shift;

                        if ($event_type eq 'ae_log') {
                            my ($severity, $message) = @_;

                            $self->get_logger()->push_to_buffer('AnyEvent::Fork::RPC log message : ' . $message . '.', 'notice')->flush_buffer(1);
                        }
                    },
                    on_error => sub {
                        $self->get_logger()->bad($connector_generic_failed_message . ' : on_error : ' . shift() . '.', 'err')->flush_buffer(1);
                    },
                    on_destroy => sub {
                        $self->get_logger()->push_to_buffer('AnyEvent::Fork::RPC : on_destroy call.', 'debug')->flush_buffer(1);
                    }
                );
                
                my $datas;

                $rpc->(
                    $self->get_connector()->get_properties(),
                    sub {
                        $datas = shift;
                    }
                );
                
                # IPC : need to wait for the children to complete here !

                return $datas;
            };
        } elsif ($connector->is_type_interpreter()) {
            $self->{__exec} = sub {
                my $self = shift;

                my ($cr, $error, $buffer, $bufferout, $buffererr) = run(
                    command => $^X . ' -M5.10.1 -Mstrict -Mwarnings ' . $self->get_connector()->get_exec_file_path()
                );

                $self->get_logger()->bad($connector_generic_failed_message . ' : ' . join('', @{$buffererr}) . '.', 'err')->flush_buffer(1) if ($error);

                return join '', @{$bufferout};
            };
        } elsif ($connector->is_type_external()) {
            $self->{__exec} = sub {
                my $self = shift;

                my ($cr, $error, $buffer, $bufferout, $buffererr) = run(
                    command => $self->get_connector()->get_exec_file_path()
                );

                $self->get_logger()->bad($connector_generic_failed_message . ' : ' . join('', @{$buffererr}) . '.', 'err')->flush_buffer(1) if ($error);

                return join '', @{$bufferout};
            };
        } elsif ($connector->is_type_plain_text()) {
            $self->{__exec} = sub {
                my $self = shift;

                local $@;

                my $datas = eval {
                    read_file($self->get_connector()->get_exec_file_path());
                };

                $self->get_logger()->bad($connector_generic_failed_message . ' : ' . $@ . '.', 'err')->flush_buffer(1) if ($@);

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

    $self->get_logger()->push_to_buffer('Execution of connector ' . $self->get_connector()->get_name() . '.', 'info')->flush_buffer(1);

    return $self->set_datas($self->get_exec()->($self));
}

sub serialize {
    my $self = shift;

    my $message = 'Get and serialize datas for connector ' . $self->get_connector()->get_name();

    $self->get_logger()->push_to_buffer($message . ' - raw datas : ' . $self->get_datas() . '.', 'debug')->flush_buffer(1) if (defined $self->get_datas());

    my $serialize = to(
        $self->get_connector(),
        $self->get_datas()
    );

    if ($serialize->[0]) {
        $self->get_logger()->good($message . '.', 'info')->flush_buffer(1);

        return $serialize->[1];
    }

    $self->get_logger()->bad($message . ' failed.', 'err')->flush_buffer(1);

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
