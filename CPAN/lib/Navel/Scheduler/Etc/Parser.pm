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

use Storable qw/
    dclone
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
                login => 'text',
                password => 'text'
            }
        }
    );

    return $validator->validate($parameters);
}

#-> methods

sub new {
    my $class = shift;

    return bless {
        __definition => {}
    }, ref $class || $class;
}

sub read {
    my $self = shift;

    $self->set_definition($self->SUPER::read(shift));

    return $self;
}

sub write {
    my $self = shift;

    $self->SUPER::write(shift, $self->get_definitions());

    return $self;
}

sub get_definition {
    my $self = shift;

    my $definition = dclone($self->{__definition});

    publicize($definition);

    return $definition;
}

sub set_definition {
    my ($self, $value) = @_;

    if (scheduler_definition_validator($value)) {
        my $value = dclone($value);

        privasize($value);

        return $self->{__definition} = $value;
    }

    return 0;
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
