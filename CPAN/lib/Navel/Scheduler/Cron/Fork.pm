# Copyright 2015 Navel-IT
# Navel Scheduler is developped by Yoann Le Garff, Nicolas Boquet and Yann Le Bras under GNU GPL v3

#-> BEGIN

#-> initialization

package Navel::Scheduler::Cron::Fork;

use strict;
use warnings;

use parent qw/
    Navel::Base
/;

use File::Slurp;

use AnyEvent::Fork;

use AnyEvent::Fork::RPC;

use Navel::Utils qw/
    :all
/;

our $VERSION = 0.1;

#-> methods

sub new {
    my ($class, $connector, $logger) = @_;
    
    local $@;

    if (blessed($connector) eq 'Navel::Definition::Connector' && blessed($logger) eq 'Navel::Logger') {
        my $code = eval {
            read_file($connector->get_exec_file_path())
        };

        my $self = {
            __connector => $connector,
            __logger => $logger,
            __fork => undef,
            __rpc => undef
        };

        unless ($@) {
            $self->{__code} = $code;

            $self->{__fork} = AnyEvent::Fork->new()->require(
                'strict',
                'warnings',
                'Navel::Utils'
            )->eval(
                $self->{__code}
            );

            $self->{__rpc} = $self->{__fork}->AnyEvent::Fork::RPC::run(
                'connector',
                on_event => sub {
                    my $event_type = shift;

                    if ($event_type eq 'ae_log') {
                        my ($severity, $message) = @_;

                        $self->get_logger()->push_to_queue('AnyEvent::Fork::RPC log message : ' . $message . '.', 'notice')->flush_queue(1);
                    }
                },
                on_error => sub {
                    $self->get_logger()->bad('Execution of connector ' . $self->{__connector}->get_name() . ' failed : ' . shift() . '.', 'err')->flush_queue(1);
                },
                on_destroy => sub {
                    $self->get_logger()->push_to_queue('AnyEvent::Fork::RPC : on_destroy call.', 'debug')->flush_queue(1);
                },
                serialiser => $AnyEvent::Fork::RPC::JSON_SERIALISER
            );
        } else {
            $self->{__logger}->bad('An error occured while reading from file ' . $self->{__connector}->get_exec_file_path() . '.', 'err')->flush_queue(1);
        }

        $class = ref $class || $class;

        return bless $self, $class;
    }

    croak('One or more objects are invalids.');
}

sub when_done {
    my ($self, $callback) = @_;

    if (defined $self->get_rpc()) {
        $self->get_rpc()->(
            $self->get_connector()->get_properties(),
            $self->get_connector()->get_input(),
            $callback
        );

        $self->get_logger()->push_to_queue('Spawned a new process.', 'debug')->flush_queue(1);

        undef $self->{__rpc};
    }

    return $self;
}

sub get_connector {
    shift->{__connector};
}

sub get_logger {
    shift->{__logger};
}

sub get_fork {
    shift->{__fork};
}

sub get_rpc {
    shift->{__rpc};
}

# sub AUTOLOAD {}

# sub DESTROY {}

1;

#-> END

__END__

=pod

=head1 NAME

Navel::Scheduler::Cron::Fork

=head1 AUTHOR

Yoann Le Garff, Nicolas Boquet and Yann Le Bras

=head1 LICENSE

GNU GPL v3

=cut