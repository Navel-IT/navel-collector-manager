# Copyright 2015 Navel-IT
# Navel Scheduler is developed by Yoann Le Garff, Nicolas Boquet and Yann Le Bras under GNU GPL v3

#-> BEGIN

#-> initialization

package Navel::RabbitMQ::Publisher;

use strict;
use warnings;

use parent qw/
    Navel::Base
/;

use Carp qw/
    carp
    croak
/;

use Net::AMQP::RabbitMQ;

use Navel::Utils qw/
    :all
/;

our $VERSION = 0.1;

our $CHANNEL_ID = 1;

#-> methods

sub new {
    my ($class, $definition) = @_;

    croak('one or more objects are invalids') unless (blessed($definition) eq 'Navel::Definition::RabbitMQ');

    bless {
        __definition => $definition,
        __net => Net::AMQP::RabbitMQ->new(),
        __queue => []
    }, ref $class || $class;
}

sub connect {
    my $self = shift;

    local $@;

    my %options = (
        user => $self->get_definition()->get_user(),
        password => $self->get_definition()->get_password(),
        port => $self->get_definition()->get_port(),
        vhost => $self->get_definition()->get_vhost()
    );

    $options{timeout} = $self->get_definition()->get_timeout() if ($self->get_definition()->get_timeout());

    eval {
        $self->get_net()->connect($self->get_definition()->get_host(), \%options);

        $self->get_net()->channel_open($CHANNEL_ID);
    };

    $@;
}

sub disconnect {
    my $self = shift;

    local $@;

    eval {
        $self->get_net()->disconnect();
    };

    $@;
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
    my ($self, $body) = @_;

    push @{$self->get_queue()}, $body;

    $self;
}

sub clear_queue {
    my $self = shift;

    undef @{$self->get_queue()};

    $self;
}

# sub AUTOLOAD {}

sub DESTROY {
    my $self = shift;

    $self->channel_close($CHANNEL_ID);

    $self->disconnect();
}

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