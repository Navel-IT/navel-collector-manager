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

use AnyEvent::Fork;
use AnyEvent::Fork::RPC;

use Navel::Utils 'blessed';

our $VERSION = 0.1;

#-> methods

sub new {
    my ($class, %options) = @_;

    $options{connector_execution_timeout} = $options{connector_execution_timeout} || 0;

    my $self = bless {
        core => $options{core},
        connector_execution_timeout => $options{connector_execution_timeout},
        connector => $options{connector},
        connector_content => $options{connector_content},
        fork => undef,
        rpc => undef
    }, ref $class || $class;

    my $connector_init_content = '
BEGIN {
    close STDOUT;
    close STDERR;
}
';

    if ($self->{connector_execution_timeout}) {
        $connector_init_content .= '
$SIG{ALRM} = sub {
    AnyEvent::Fork::RPC::event("execution timeout after ' . $self->{connector_execution_timeout} . ' second' . ($self->{connector_execution_timeout} > 1 ? 's' : '') . '");

    exit;
};

alarm ' . $self->{connector_execution_timeout} . ';
';
    }

    $self->{fork} = AnyEvent::Fork->new()->eval($connector_init_content . $self->{connector_content} . '
sub __connector {
    connector(@_);
}');

    $self->{rpc} = $self->{fork}->AnyEvent::Fork::RPC::run(
        '__connector',
        on_event => sub {
            $self->{core}->{logger}->push_in_queue(
                message => 'AnyEvent::Fork::RPC event message for connector ' . $self->{connector}->{name} . ': ' . shift() . '.',
                severity => 'notice'
            );
        },
        on_error => sub {
            $self->{core}->{logger}->bad(
                message => 'Execution of connector ' . $self->{connector}->{name} . ' failed (fatal error): ' . shift() . '.',
                severity => 'err'
            );

            $self->{core}->a_connector_stop(
                connector => $self->{connector},
                event_definition => {
                    connector => $self->{connector}
                },
                status_method => 'set_ko_exception'
            );
        },
        on_destroy => sub {
            $self->{core}->{logger}->push_in_queue(
                message => 'AnyEvent::Fork::RPC DESTROY() called.',
                severity => 'debug'
            );
        },
        serialiser => SEREAL_SERIALISER
    );

    $self;
}

sub when_done {
    my ($self, %options) = @_;

    if (defined $self->{rpc}) {
        $self->{rpc}->(
            $self->{connector}->properties(),
            $self->{connector}->{input},
            $options{callback}
        );

        $self->{core}->{logger}->push_in_queue(
            message => 'Spawned a new process for connector ' . $self->{connector}->{name} . '.',
            severity => 'debug'
        );

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

