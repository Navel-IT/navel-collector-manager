# Copyright 2015 Navel-IT
# Navel Scheduler is developed by Yoann Le Garff, Nicolas Boquet and Yann Le Bras under GNU GPL v3

#-> BEGIN

#-> initialization

package Navel::Scheduler;

use strict;
use warnings;

use parent qw/
    Navel::Base
/;

use Exporter::Easy (
    OK => [qw/
        $VERSION
        :all
    /],
    TAGS => [
        all => [qw/
            $VERSION
        /]
    ]
);

use Carp qw/
    carp
    croak
/;

use Navel::Scheduler::Cron;

use Navel::Scheduler::Etc::Parser;

use Navel::Definition::Connector::Etc::Parser;

use Navel::Definition::RabbitMQ::Etc::Parser;

use Navel::Utils qw/
    :all
/;

our $VERSION = 0.1;

#-> methods

sub new {
    my ($class, $configuration_path) = @_;

    croak('general configuration file path is missing') unless (defined $configuration_path);

    bless {
        __core => undef,
        __configuration => Navel::Scheduler::Etc::Parser->new()->read($configuration_path)->make()
    }, ref $class || $class;
}

sub run {
    my ($self, $logger) = @_;

    my $connectors = Navel::Definition::Connector::Etc::Parser->new()->read($self->get_configuration()->get_definition()->{connectors}->{definitions_from_file})->make(
        {
            exec_directory_path => $self->get_configuration()->get_definition()->{connectors}->{connectors_exec_directory}
        }
    );

    my $rabbitmq = Navel::Definition::RabbitMQ::Etc::Parser->new()->read($self->get_configuration()->get_definition()->{rabbitmq}->{definitions_from_file})->make();

    $self->{__core} = Navel::Scheduler::Cron->new($connectors, $rabbitmq, $logger);

    my $run = $self->get_core()->register_logger()->register_connectors()->init_publishers();

    for (@{$self->get_core()->get_publishers()}) {
        $self->get_core()->connect_publisher($_->get_definition()->get_name()) if ($_->get_definition()->get_auto_connect());
    }

    $run->register_publishers()->start();

    $self;
}

sub get_core {
    shift->{__core};
}

sub get_configuration {
    shift->{__configuration};
}

# sub AUTOLOAD {}

# sub DESTROY {}

1;

#-> END

__END__

=pod

=head1 NAME

Navel::Scheduler

=head1 AUTHOR

Yoann Le Garff, Nicolas Boquet and Yann Le Bras

=head1 LICENSE

GNU GPL v3

=cut
