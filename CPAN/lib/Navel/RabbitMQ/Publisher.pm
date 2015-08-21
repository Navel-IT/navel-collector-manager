# Copyright 2015 Navel-IT
# Navel Scheduler is developed by Yoann Le Garff, Nicolas Boquet and Yann Le Bras under GNU GPL v3

#-> BEGIN

#-> initialization

package Navel::RabbitMQ::Publisher;

use strict;
use warnings;

use parent 'Navel::Base';

use Carp 'croak';

use AnyEvent::RabbitMQ 1.19;

use Navel::RabbitMQ::Publisher::Event;
use Navel::Utils 'blessed';

our $VERSION = 0.1;

#-> methods

sub new {
    my ($class, $definition) = @_;

    croak('one or more objects are invalids') unless (blessed($definition) eq 'Navel::Definition::RabbitMQ');

    bless {
        definition => $definition,
        net => undef,
        queue => []
    }, ref $class || $class;
}

sub connect {
    my ($self, $callbacks) = @_;

    croak('one or more callbacks are not coderef') unless (ref $callbacks eq 'HASH' && ref $callbacks->{on_success} eq 'CODE' && ref $callbacks->{on_failure} eq 'CODE' && ref $callbacks->{on_read_failure} eq 'CODE' && ref $callbacks->{on_return} eq 'CODE' && ref $callbacks->{on_close} eq 'CODE');

    $self->{net} = AnyEvent::RabbitMQ->new()->load_xml_spec()->connect(
        host => $self->{definition}->{host},
        port => $self->{definition}->{port},
        user => $self->{definition}->{user},
        pass => $self->{definition}->{password},
        vhost => $self->{definition}->{vhost},
        timeout => $self->{definition}->{timeout},
        tls => $self->{definition}->{tls},
        tune => {
            heartbeat => $self->{definition}->{heartbeat}
        },
        on_success => $callbacks->{on_success},
        on_failure => $callbacks->{on_failure},
        on_read_failure => $callbacks->{on_read_failure},
        on_return => $callbacks->{on_return},
        on_close => $callbacks->{on_close}
    );

    $self;
}

sub disconnect {
    my $self = shift;

    undef $self->{net};

    $self;
}

sub is_connected {
    my $self = shift;

    blessed($self->{net}) eq 'AnyEvent::RabbitMQ' && $self->{net}->is_open();
}

sub clear_queue {
    my $self = shift;

    undef @{$self->{queue}};

    $self;
}

sub push_in_queue {
    my ($self, $definition, $status_method) = @_;

    my $event = Navel::RabbitMQ::Publisher::Event->new($definition);

    $event->$status_method() if (defined $status_method);

    push @{$self->{queue}}, $event;

    $self;
}

# sub AUTOLOAD {}

# sub DESTROY {}

1;

#-> END

__END__

=pod

=head1 NAME

Navel::RabbitMQ::Publisher

=head1 AUTHOR

Yoann Le Garff, Nicolas Boquet and Yann Le Bras

=head1 LICENSE

GNU GPL v3

=cut
