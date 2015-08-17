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
        __definition => $definition,
        __net => undef,
        __queue => []
    }, ref $class || $class;
}

sub connect {
    my ($self, $callbacks) = @_;

    croak('one or more callbacks are not coderef') unless (ref $callbacks eq 'HASH' && ref $callbacks->{on_success} eq 'CODE' && ref $callbacks->{on_failure} eq 'CODE' && ref $callbacks->{on_read_failure} eq 'CODE' && ref $callbacks->{on_return} eq 'CODE' && ref $callbacks->{on_close} eq 'CODE');

    $self->{__net} = AnyEvent::RabbitMQ->new()->load_xml_spec()->connect(
        host => $self->get_definition()->get_host(),
        port => $self->get_definition()->get_port(),
        user => $self->get_definition()->get_user(),
        pass => $self->get_definition()->get_password(),
        vhost => $self->get_definition()->get_vhost(),
        timeout => $self->get_definition()->get_timeout(),
        tls => $self->get_definition()->get_tls(),
        tune => {
            heartbeat => $self->get_definition()->get_heartbeat()
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

    undef $self->{__net};

    $self;
}

sub is_connected {
    my $self = shift;

    blessed($self->get_net()) eq 'AnyEvent::RabbitMQ' && $self->get_net()->is_open();
}

sub get_definition {
    shift->{__definition};
}

sub get_net {
    shift->{__net};
}

sub get_queue {
    shift->{__queue};
}

sub push_in_queue {
    my ($self, $definition, $status_method) = @_;

    my $event = Navel::RabbitMQ::Publisher::Event->new($definition);

    $event->$status_method() if (defined $status_method);

    push @{$self->get_queue()}, $event;

    $self;
}

sub clear_queue {
    my $self = shift;

    undef @{$self->get_queue()};

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