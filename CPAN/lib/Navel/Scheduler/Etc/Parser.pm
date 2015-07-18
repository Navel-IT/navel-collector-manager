# Copyright 2015 Navel-IT
# Navel Scheduler is developed by Yoann Le Garff, Nicolas Boquet and Yann Le Bras under GNU GPL v3

#-> BEGIN

#-> initialization

package Navel::Scheduler::Etc::Parser;

use strict;
use warnings;

use parent qw/
    Navel::Base
    Navel::Base::Definition::Etc::Parser::Reader
    Navel::Base::Definition::Etc::Parser::Writer
/;

use Exporter::Easy (
    OK => [qw/
        :all
        scheduler_definition_validator
    /],
    TAGS => [
        all => [qw/
            scheduler_definition_validator
        /]
    ]
);

use Carp qw/
    carp
    croak
/;

use Storable qw/
    dclone
/;

use Scalar::Util::Numeric qw/
    isint
    isfloat
/;

use Data::Validate::Struct;

use Navel::Utils qw/
    :all
/;

our $VERSION = 0.1;

#-> functions

sub scheduler_definition_validator($) {
    my $parameters = shift;

    my $validator = Data::Validate::Struct->new(
        {
            definitions_path => {
                connectors => 'text',
                connectors_exec_directory => 'text',
                rabbitmq => 'text'
            },
            webservices => {
                credentials => {
                    login => 'text',
                    password => 'text'
                },
                mojo_server => 'general_mojo_server'
            }
        }
    );

    $validator->type(
        general_mojo_server => sub {
            my $value = shift;

            my $customs_options_ok = 0;

            if (ref $value eq 'HASH') {
                $customs_options_ok = 1;

                my $properties_type = {
                    # Mojo::Server
                    reverse_proxy => \&isint,
                    # Mojo::Server::Daemon
                    backlog => \&isint,
                    inactivity_timeout => \&isint,
                    max_clients => \&isint,
                    max_requests => \&isint,
                    # Mojo::Server::Prefork
                    accepts => \&isint,
                    accept_interval => \&isfloat,
                    graceful_timeout => \&isfloat,
                    heartbeat_interval => \&isfloat,
                    heartbeat_timeout => \&isfloat,
                    multi_accept => \&isint,
                    workers => \&isint
                };

                while (my ($property, $type) = each %{$properties_type}) {
                    $customs_options_ok = 0 if (exists $value->{$property} && ! $type->($value->{$property}));
                }
            }

            $customs_options_ok;
        }
    );

    $validator->validate($parameters);
}

#-> methods

sub new {
    my $class = shift;

    bless {
        __definition => {}
    }, ref $class || $class;
}

sub read {
    my $self = shift;

    $self->set_definition($self->SUPER::read(shift));

    $self;
}

sub write {
    my $self = shift;

    $self->SUPER::write(shift, $self->get_definition());

    $self;
}

sub make {
    my $self = shift;

    croak('general definition is invalid') unless (scheduler_definition_validator($self->get_definition()));

    $self;
}

sub get_definition {
    my $self = shift;

    my $definition = dclone($self->{__definition});

    publicize($definition);

    $definition;
}

sub set_definition {
    my ($self, $value) = @_;

    if (scheduler_definition_validator($value)) {
        my $value = dclone($value);

        privasize($value);

        $self->{__definition} = $value;

        1;
    }
}

# sub AUTOLOAD {}

# sub DESTROY {}

1;

#-> END

__END__

=pod

=head1 NAME

Navel::Scheduler::Etc::Parser

=head1 AUTHOR

Yoann Le Garff, Nicolas Boquet and Yann Le Bras

=head1 LICENSE

GNU GPL v3

=cut
