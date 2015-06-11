# Copyright 2015 Navel-IT
# Navel Scheduler is developed by Yoann Le Garff, Nicolas Boquet and Yann Le Bras under GNU GPL v3

#-> BEGIN

#-> initialization

package Navel::Definition::Connector;

use strict;
use warnings;

use parent qw/
    Navel::Base::Definition
/;

use constant {
    CONNECTOR_TYPE_CODE => 'code',
    CONNECTOR_TYPE_JSON => 'json'
};

use Exporter::Easy (
    OK => [qw/
        :all
        connector_definition_validator
    /],
    TAGS => [
        all => [qw/
            connector_definition_validator
        /]
    ]
);

use Data::Validate::Struct;

use DateTime::Event::Cron::Quartz;

use Navel::Utils qw/
    :all
/;

our $VERSION = 0.1;

#-> functions

sub connector_definition_validator($) {
    my $parameters = shift;

    my $validator = Data::Validate::Struct->new(
        {
            name => 'word',
            collection => 'word',
            type => 'connector_type',
            scheduling => 'connector_cron',
            exec_directory_path => 'text'
        }
    );

    $validator->type(
        connector_type => sub {
            my $value = shift;

            return $value eq CONNECTOR_TYPE_CODE || $value eq CONNECTOR_TYPE_JSON;
        },
        connector_cron => sub {
            return eval {
                DateTime::Event::Cron::Quartz->new(shift);
            };
        }
    );

    return $validator->validate($parameters) && (exists $parameters->{source} and ! defined $parameters->{source} || $parameters->{source} =~ /^[\w_\-]+$/) && exists $parameters->{input}; # sadly, Data::Validate::Struct doesn't work with undef value
}

#-> methods

sub new {
    return shift->SUPER::new(
        \&connector_definition_validator,
        shift
    );
}

sub set_generic {
   return shift->SUPER::set_generic(
        \&connector_definition_validator,
        shift,
        shift
   );
}

sub get_collection {
    return shift->{__collection};
}

sub set_collection {
    return shift->set_generic('collection', shift);
}

sub get_type {
    return shift->{__type};
}

sub is_type_code {
    return shift->get_type() eq CONNECTOR_TYPE_CODE;
}

sub is_type_json {
    return shift->get_type() eq CONNECTOR_TYPE_JSON;
}

sub set_type {
    return shift->set_generic('type', shift);
}

sub get_scheduling {
    return shift->{__scheduling};
}

sub set_scheduling {
    return shift->set_generic('scheduling', shift);
}

sub get_source {
    return shift->{__source};
}

sub set_source {
    return shift->set_generic('source', shift);
}

sub get_input {
    return shift->{__input};
}

sub set_input {
    return shift->set_generic('input', shift);
}

sub get_exec_directory_path {
    return shift->{__exec_directory_path};
}

sub get_exec_file_path {
    my $self = shift;

    return $self->get_exec_directory_path() . '/' . ($self->get_source() || $self->get_name());
}

# sub AUTOLOAD {}

# sub DESTROY {}

1;

#-> END

__END__

=pod

=head1 NAME

Navel::Definition::Connector

=head1 AUTHOR

Yoann Le Garff, Nicolas Boquet and Yann Le Bras

=head1 LICENSE

GNU GPL v3

=cut
