# Copyright 2015 Navel-IT
# Navel Scheduler is developed by Yoann Le Garff, Nicolas Boquet and Yann Le Bras under GNU GPL v3

#-> BEGIN

#-> initialization

package Navel::Definition::WebService;

use strict;
use warnings;

use parent qw/
    Navel::Base::Definition
/;

use Exporter::Easy (
    OK => [qw/
        :all
        web_service_definition_validator
    /],
    TAGS => [
        all => [qw/
            web_service_definition_validator
        /]
    ]
);

use Scalar::Util::Numeric qw/
    isint
/;

use Data::Validate::Struct;

use Mojo::URL;

use Navel::Utils qw/
    :all
/;

our $VERSION = 0.1;

our @ORIGINAL_PROPERTIES = qw/
    name
    interface_mask
    port
    tls
/;

#-> functions

sub web_service_definition_validator($) {
    my $parameters = shift;

    my $validator = Data::Validate::Struct->new(
        {
            name => 'word',
            interface_mask => 'text',
            port => 'port',
            tls => 'web_service_tls'
        }
    );

    $validator->type(
        web_service_tls => sub {
            my $value = shift;

            isint($value) && ($value == 0 || $value == 1);
        }
    );

    $validator->validate($parameters);
}

#-> methods

sub new {
    shift->SUPER::new(
        \&web_service_definition_validator,
        shift
    );
}

sub merge {
   shift->SUPER::merge(
        \&web_service_definition_validator,
        shift
   );
}

sub get_original_properties {
    shift->SUPER::get_original_properties(\@ORIGINAL_PROPERTIES);
}

sub set_name {
    shift->merge(
        {
            name => shift
        }
    );
}

sub get_interface_mask {
    shift->{__interface_mask};
}

sub set_interface_mask {
    shift->merge(
        {
            interface_mask => shift
        }
    );
}

sub get_port {
    shift->{__port};
}

sub set_port {
    shift->merge(
        {
            port => shift
        }
    );
}

sub get_tls {
    shift->{__tls};
}

sub set_tls {
    shift->merge(
        {
            tls => shift
        }
    );
}

sub get_url {
    my $self = shift;

    Mojo::URL->new()->scheme(
        'http' . ($self->get_tls() ? 's' : '')
    )->host(
        $self->get_interface_mask()
    )->port(
        $self->get_port()
    );
}

# sub AUTOLOAD {}

# sub DESTROY {}

1;

#-> END

__END__

=pod

=head1 NAME

Navel::Definition::WebService

=head1 AUTHOR

Yoann Le Garff, Nicolas Boquet and Yann Le Bras

=head1 LICENSE

GNU GPL v3

=cut
