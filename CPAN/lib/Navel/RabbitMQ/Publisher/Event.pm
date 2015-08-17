# Copyright 2015 Navel-IT
# Navel Scheduler is developed by Yoann Le Garff, Nicolas Boquet and Yann Le Bras under GNU GPL v3

#-> BEGIN

#-> initialization

package Navel::RabbitMQ::Publisher::Event;

use strict;
use warnings;

use constant {
    OK => 0,
    KO_NO_SOURCE => 1,
    KO_EXCEPTION => 2
};

use parent 'Navel::Base';

use Carp 'croak';

use Navel::RabbitMQ::Serialize::Data 'to';
use Navel::Utils 'blessed';

our $VERSION = 0.1;

#-> methods

sub new {
    my ($class, $definition) = @_;

    croak('event definition is invalid') unless (ref $definition eq 'HASH');

    my $self = bless {}, ref $class || $class;

    if (blessed($definition->{connector}) eq 'Navel::Definition::Connector') {
        $self->{connector} = $definition->{connector};
        $self->{collection} = $self->{connector}->{collection};
    } else {
        croak('collection cannot be undefined') unless (defined $definition->{collection});

        $self->{connector} = undef;
        $self->{collection} = $definition->{collection};
    }

    $self->set_ok();
    $self->{datas} = $definition->{datas};

    $self;
}

sub set_ok {
    my $self = shift;

    $self->{status_code} = OK;

    $self;
}

sub set_ko_no_source {
    my $self = shift;

    $self->{status_code} = KO_NO_SOURCE;

    $self;
}

sub set_ko_exception {
    my $self = shift;

    $self->{status_code} = KO_EXCEPTION;

    $self;
}

sub serialized_datas {
    my $self = shift;

    to(
        $self->{datas},
        $self->{connector},
        $self->{collection}
    );
}


sub routing_key {
    my $self = shift;

    join '.', 'navel', $self->{collection}, $self->{status_code};
}

# sub AUTOLOAD {}

# sub DESTROY {}

1;

#-> END

__END__

=pod

=head1 NAME

Navel::RabbitMQ::Publisher::Event

=head1 AUTHOR

Yoann Le Garff, Nicolas Boquet and Yann Le Bras

=head1 LICENSE

GNU GPL v3

=cut
