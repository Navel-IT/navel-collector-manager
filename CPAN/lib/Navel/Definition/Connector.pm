# Copyright 2015 Navel-IT
# Navel Scheduler is developed by Yoann Le Garff, Nicolas Boquet and Yann Le Bras under GNU GPL v3

#-> BEGIN

#-> initialization

package Navel::Definition::Connector;

use strict;
use warnings;

use parent 'Navel::Base::Definition';

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

use Scalar::Util::Numeric 'isint';

use DateTime::Event::Cron::Quartz;

our $VERSION = 0.1;

our @RUNTIME_PROPERTIES = qw/
    exec_directory_path
/;

#-> functions

sub connector_definition_validator($) {
    my $parameters = shift;

    my $validator = Data::Validate::Struct->new(
        {
            name => 'word',
            collection => 'word',
            type => 'connector_type',
            singleton => 'connector_singleton',
            scheduling => 'connector_cron',
            exec_directory_path => 'text'
        }
    );

    $validator->type(
        connector_type => sub {
            my $value = shift;

            $value eq CONNECTOR_TYPE_CODE || $value eq CONNECTOR_TYPE_JSON;
        },
        connector_singleton => sub {
            my $value = shift;

            $value == 0 || $value == 1 if (isint($value));
        },
        connector_cron => sub {
            eval {
                DateTime::Event::Cron::Quartz->new(shift);
            };
        }
    );

    $validator->validate($parameters) && (exists $parameters->{source} and ! defined $parameters->{source} || $parameters->{source} =~ /^[\w_\-]+$/) && exists $parameters->{input}; # unfortunately, Data::Validate::Struct doesn't work with undef (JSON's null) value
}

#-> methods

sub new {
    shift->SUPER::new(
        \&connector_definition_validator,
        shift
    );
}

sub merge {
   shift->SUPER::merge(
        \&connector_definition_validator,
        shift
   );
}

sub get_original_properties {
    shift->SUPER::get_original_properties(\@RUNTIME_PROPERTIES);
}

sub set_name {
    shift->merge(
        {
            name => shift
        }
    );
}

sub get_collection {
    shift->{__collection};
}

sub set_collection {
    shift->merge(
        {
            collection => shift
        }
    );
}

sub get_type {
    shift->{__type};
}

sub is_type_code {
    shift->get_type() eq CONNECTOR_TYPE_CODE;
}

sub is_type_json {
    shift->get_type() eq CONNECTOR_TYPE_JSON;
}

sub set_type {
    shift->merge(
        {
            type => shift
        }
    );
}

sub get_singleton {
    shift->{__singleton};
}

sub set_singleton {
    shift->merge(
        {
            singleton => shift
        }
    );
}

sub get_scheduling {
    shift->{__scheduling};
}

sub set_scheduling {
    shift->merge(
        {
            scheduling => shift
        }
    );
}

sub get_source {
    shift->{__source};
}

sub set_source {
    shift->merge(
        {
            source => shift
        }
    );
}

sub get_input {
    shift->{__input};
}

sub set_input {
    shift->merge(
        {
            input => shift
        }
    );
}

sub get_exec_directory_path {
    shift->{__exec_directory_path};
}

sub set_exec_directory_path {
    shift->merge(
        {
            exec_directory_path => shift
        }
    );
}

sub get_exec_file_path {
    my $self = shift;

    $self->get_exec_directory_path() . '/' . ($self->get_source() || $self->get_name());
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
