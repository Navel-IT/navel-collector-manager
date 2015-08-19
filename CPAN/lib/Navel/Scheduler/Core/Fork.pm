# Copyright 2015 Navel-IT
# Navel Scheduler is developed by Yoann Le Garff, Nicolas Boquet and Yann Le Bras under GNU GPL v3

#-> BEGIN

#-> initialization

package Navel::Scheduler::Core::Fork;

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

use Carp 'croak';

use AnyEvent::Fork;
use AnyEvent::Fork::RPC;

use Navel::Utils 'blessed';

our $VERSION = 0.1;

#-> methods

sub new {
    my ($class, $connector, $perl_code_string, $publishers, $logger) = @_;

    croak('one or more objects are invalids.') unless (blessed($connector) eq 'Navel::Definition::Connector' && blessed($logger) eq 'Navel::Logger' && ref $publishers eq 'ARRAY');

    for (@{$publishers}) {
        croak('one or more publisher objects are invalids.') unless (blessed($_) eq 'Navel::RabbitMQ::Publisher');
    }

    my $self = bless {
        connector => $connector,
        perl_code_string => $perl_code_string,
        logger => $logger,
        publishers => $publishers,
        fork => undef,
        rpc => undef
    }, ref $class || $class;

    $self->{fork} = AnyEvent::Fork->new()->require(
        'strict',
        'warnings'
    )->eval(
        $self->{perl_code_string}
    );

    $self->{rpc} = $self->{fork}->AnyEvent::Fork::RPC::run(
        'connector',
        on_event => sub {
            my $event_type = shift;

            if ($event_type eq 'ae_log') {
                my ($severity, $message) = @_;

                $self->{logger}->push_in_queue('AnyEvent::Fork::RPC event message : ' . $message . '.', 'notice');
            }
        },
        on_error => sub {
            $self->{logger}->bad('Execution of connector ' . $self->{connector}->{name} . ' failed (fatal error) : ' . shift() . '.', 'err');

            $_->push_in_queue(
                {
                    connector => $connector
                },
                'set_ko_exception'
            ) for (@{$self->{publishers}});
        },
        on_destroy => sub {
            $self->{logger}->push_in_queue('AnyEvent::Fork::RPC : destroy called.', 'debug');
        },
        serialiser => SEREAL_SERIALISER
    );

    $self;
}

sub when_done {
    my ($self, $callback) = @_;

    if (defined $self->{rpc}) {
        $self->{rpc}->(
            $self->{connector}->properties(),
            $self->{connector}->{input},
            $callback
        );

        $self->{logger}->push_in_queue('Spawned a new process.', 'debug');

        undef $self->{rpc};
    }

    $self;
}

# sub AUTOLOAD {}

# sub DESTROY {}

1;

#-> END

__END__

=pod

=head1 NAME

Navel::Scheduler::Core::Fork

=head1 AUTHOR

Yoann Le Garff, Nicolas Boquet and Yann Le Bras

=head1 LICENSE

GNU GPL v3

=cut
