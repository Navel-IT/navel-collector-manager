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

use Data::Validate::Struct;

use Scalar::Util::Numeric qw/
    isint
/;

use Mojo::URL;

our $VERSION = 0.1;

our @RUNTIME_PROPERTIES;

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

            $value == 0 or $value == 1 if (isint($value));
        }
    );

    $validator->validate($parameters) && exists $parameters->{ca} && exists $parameters->{cert} && exists $parameters->{ciphers} && exists $parameters->{key} && exists $parameters->{verify}; # unfortunately, Data::Validate::Struct doesn't work with undef (JSON's null) value
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
    shift->SUPER::get_original_properties(\@RUNTIME_PROPERTIES);
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

sub get_ca {
    shift->{__ca};
}

sub set_ca {
    shift->merge(
        {
            ca => shift
        }
    );
}

sub get_cert {
    shift->{__cert};
}

sub set_cert {
    shift->merge(
        {
            cert => shift
        }
    );
}

sub get_ciphers {
    shift->{__ciphers};
}

sub set_ciphers {
    shift->merge(
        {
            ciphers => shift
        }
    );
}

sub get_key {
    shift->{__key};
}

sub set_key {
    shift->merge(
        {
            key => shift
        }
    );
}

sub get_verify {
    shift->{__verify};
}

sub set_verify {
    shift->merge(
        {
            verify => shift
        }
    );
}

sub get_url {
    my $self = shift;

    my $url = Mojo::URL->new()->scheme(
        'http' . ($self->get_tls() ? 's' : '')
    )->host(
        $self->get_interface_mask()
    )->port(
        $self->get_port()
    );

    $url->query(ca => $self->get_ca()) if (defined $self->get_ca());
    $url->query(cert => $self->get_cert()) if (defined $self->get_cert());
    $url->query(ciphers => $self->get_ciphers()) if (defined $self->get_ciphers());
    $url->query(key => $self->get_key()) if (defined $self->get_key());
    $url->query(verify => $self->get_verify()) if (defined $self->get_verify());

    $url;
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
