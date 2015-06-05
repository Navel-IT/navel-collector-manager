# Copyright 2015 Navel-IT
# Navel Scheduler is developped by Yoann Le Garff, Nicolas Boquet and Yann Le Bras under GNU GPL v3

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

#-> methods

sub new {
    my ($class, $definition) = @_;

    if (blessed($definition) eq 'Navel::Definition::RabbitMQ') {
        $class = ref $class || $class;

        return bless {
            __definition => $definition,
            __net => Net::AMQP::RabbitMQ->new(),
            __buffer => []
        }, $class;
    }

    croak('One or more objects are invalids');
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
    };

    return $@;
}

sub disconnect {
    my $self = shift;

    eval {
        $self->get_net()->disconnect();
    };

    return $@;
}

sub get_definition {
    return shift->{__definition};
}

sub get_net {
    return shift->{__net};
}

sub get_buffer {
    return shift->{__buffer};
}

sub push_in_buffer {
    my ($self, $body) = @_;

    push @{$self->get_buffer()}, $body;

    return $self;
}

sub clear_buffer {
    my $self = shift;

    undef @{$self->get_buffer()};

    return $self;
}

# sub AUTOLOAD {}

sub DESTROY {
    shift->disconnect();
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