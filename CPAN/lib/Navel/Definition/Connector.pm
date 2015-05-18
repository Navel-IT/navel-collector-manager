# Copyright 2015 Navel-IT
# Navel Scheduler is developped by Yoann Le Garff, Nicolas Boquet and Yann Le Bras under GNU GPL v3

#-> BEGIN

#-> initialization

package Navel::Definition::Connector;

use strict;
use warnings;

use parent qw/
    Navel::Base::Definition
/;

use constant {
    CODE => 'code',
    EXTERNAL => 'external',
    PLAIN_TEXT => 'text'
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

use DateTime::Event::Cron;

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

            return $value eq CODE || $value eq EXTERNAL || $value eq PLAIN_TEXT;
        },
        connector_cron => sub {
            eval {
                DateTime::Event::Cron->from_cron(shift);
            };

            return ! $@;
        }
    );

    return $validator->validate($parameters);
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
    return shift->get_type() eq CODE;
}

sub is_type_external {
    return shift->get_type() eq EXTERNAL;
}

sub is_type_plain_text {
    return shift->get_type() eq PLAIN_TEXT;
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

sub get_exec_directory_path {
    return shift->{__exec_directory_path};
}

sub get_exec_file_path {
    my $self = shift;

    return $self->get_exec_directory_path() . '/' . $self->get_name();
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