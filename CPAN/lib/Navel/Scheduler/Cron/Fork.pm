# Copyright 2015 Navel-IT
# Navel Scheduler is developed by Yoann Le Garff, Nicolas Boquet and Yann Le Bras under GNU GPL v3

#-> BEGIN

#-> initialization

package Navel::Scheduler::Cron::Fork;

use strict;
use warnings;

use parent 'Navel::Base';

use constant {
    SEREAL_SERIALISER => '
use Sereal;

(
    sub {
        Sereal::Encoder->new()->encode(\@_);
    },
    sub {
        @{Sereal::Decoder->new()->decode(shift)};
    }
);
    '
};

use AnyEvent::Fork;
use AnyEvent::Fork::RPC;

use Navel::Utils 'blessed';

our $VERSION = 0.1;

#-> methods

sub new {
    my ($class, $connector, $perl_code_string, $logger, $publishers) = @_;

    croak('one or more objects are invalids.') unless (blessed($connector) eq 'Navel::Definition::Connector' && blessed($logger) eq 'Navel::Logger' && ref $publishers eq 'ARRAY');

    for (@{$publishers}) {
        croak('one or more publisher objects are invalids.') unless ($_ eq 'Navel::RabbitMQ::Publisher');
    }

    my $self = bless {
        __connector => $connector,
        __perl_code_string => $perl_code_string,
        __logger => $logger,
        __publishers => $publishers,
        __fork => undef,
        __rpc => undef
    }, ref $class || $class;

    $self->{__fork} = AnyEvent::Fork->new()->require(
        'strict',
        'warnings'
    )->eval(
        $self->get_perl_code_string()
    );

    $self->{__rpc} = $self->get_fork()->AnyEvent::Fork::RPC::run(
        'connector',
        on_event => sub {
            my $event_type = shift;

            if ($event_type eq 'ae_log') {
                my ($severity, $message) = @_;

                $self->get_logger()->push_in_queue('AnyEvent::Fork::RPC event message : ' . $message . '.', 'notice');
            }
        },
        on_error => sub {
            $self->get_logger()->bad('Execution of connector ' . $self->{__connector}->get_name() . ' failed (fatal error) : ' . shift() . '.', 'err');

            $_->push_in_queue(
                {
                    connector => $connector
                },
                'set_ko_exception'
            ) for (@{$self->get_publishers()});
        },
        on_destroy => sub {
            $self->get_logger()->push_in_queue('AnyEvent::Fork::RPC : destroy called.', 'debug');
        },
        serialiser => SEREAL_SERIALISER
    );

    $self;
}

sub when_done {
    my ($self, $callback) = @_;

    if (defined $self->get_rpc()) {
        $self->get_rpc()->(
            $self->get_connector()->get_properties(),
            $self->get_connector()->get_input(),
            $callback
        );

        $self->get_logger()->push_in_queue('Spawned a new process.', 'debug');

        undef $self->{__rpc};
    }

    $self;
}

sub get_connector {
    shift->{__connector};
}

sub get_perl_code_string {
    shift->{__perl_code_string};
}

sub get_logger {
    shift->{__logger};
}

sub get_publishers {
    shift->{__publishers};
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
