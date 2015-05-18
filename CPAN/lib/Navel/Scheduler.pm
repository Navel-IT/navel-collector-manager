# Copyright 2015 Navel-IT
# Navel Scheduler is developped by Yoann Le Garff, Nicolas Boquet and Yann Le Bras under GNU GPL v3

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
        my $configuration = Navel::Scheduler::Etc::Parser->new();
        
        my $return = $configuration->load($configuration_path);
        
        if ($return->[0]) {
            my $connectors = Navel::Definition::Connector::Etc::Parser->new();

            $return = $connectors->load($configuration->get_definition()->{definitions_path}->{connectors});

            if ($return->[0]) {
                $return = $connectors->make(
                    {
                        exec_directory_path => $configuration->get_definition()->{definitions_path}->{connectors_exec_directory}
                    }
                );

                if ($return->[0]) {
                    my $rabbitmq = Navel::Definition::RabbitMQ::Etc::Parser->new();

                    $return = $rabbitmq->load($configuration->get_definition()->{definitions_path}->{rabbitmq});

                    if ($return->[0]) {
                        $return = $rabbitmq->make();

                        if ($return->[0]) {
                            my $self = {
                                __core => Navel::Scheduler::Cron->new(
                                    $connectors,
                                    $rabbitmq
                                ),
                                __configuration => $configuration
                            };

                            $class = ref $class || $class;

                            return bless $self, $class;
                        }
                    }
                }
            }
        }
        
        croak($return->[1]);
    } else {
        croak('general.json path are missing');
    }
}

sub run {
    my $self = shift;

    $self->get_core()->start();

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