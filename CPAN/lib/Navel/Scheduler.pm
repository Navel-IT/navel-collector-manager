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

use String::Util qw/
    hascontent
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

    if (hascontent($configuration_path)) {
        $class = ref $class || $class;

        return bless {
            __core => undef,
            __configuration => Navel::Scheduler::Etc::Parser->new()->read($configuration_path)
        }, $class;
    } else {
        croak('<general>.json path is missing');
    }
}

sub run {
    my ($self, $logger) = @_;

    my $connectors = Navel::Definition::Connector::Etc::Parser->new()->read($self->get_configuration()->get_definition()->{definitions_path}->{connectors})->make(
        {
            exec_directory_path => $self->get_configuration()->get_definition()->{definitions_path}->{connectors_exec_directory}
        }
    );

    my $rabbitmq = Navel::Definition::RabbitMQ::Etc::Parser->new()->read($self->get_configuration()->get_definition()->{definitions_path}->{rabbitmq})->make();

    $self->{__core} = Navel::Scheduler::Cron->new($connectors, $rabbitmq, $logger);

    $self->get_core()->register_logger()->register_connectors()->init_publishers()->connect_publishers()->register_publishers()->start();

    return $self;
}

sub get_core {
    return shift->{__core};
}

sub get_configuration {
    return shift->{__configuration};
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
