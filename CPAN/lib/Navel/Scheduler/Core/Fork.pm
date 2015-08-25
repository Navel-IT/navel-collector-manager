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
    my ($class, $core, $connector, $connector_content) = @_;

    croak('one or more objects are invalids.') unless (blessed($core) eq 'Navel::Scheduler::Core' && blessed($connector) eq 'Navel::Definition::Connector');

    my $self = bless {
        core => $core,
        connector => $connector,
        connector_content => $connector_content,
        fork => undef,
        rpc => undef
    }, ref $class || $class;

    $self->{fork} = AnyEvent::Fork->new()->eval('
BEGIN {
    close STDOUT;
    close STDERR;
}
    ' . $self->{connector_content} . '
sub __connector {
    connector(@_);
}');

    $self->{rpc} = $self->{fork}->AnyEvent::Fork::RPC::run(
        '__connector',
        on_event => sub {
            $self->{core}->{logger}->push_in_queue('AnyEvent::Fork::RPC event message : ' . shift() . '.', 'notice');
        },
        on_error => sub {
            $self->{core}->{logger}->bad('Execution of connector ' . $self->{connector}->{name} . ' failed (fatal error) : ' . shift() . '.', 'err');

            $self->{core}->a_connector_stop(
                $self->{connector},
                {
                    connector => $self->{connector}
                },
                'set_ko_exception'
            );
        },
        on_destroy => sub {
            $self->{core}->{logger}->push_in_queue('AnyEvent::Fork::RPC : destroy called.', 'debug');
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

        $self->{core}->{logger}->push_in_queue('Spawned a new process.', 'debug');

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

