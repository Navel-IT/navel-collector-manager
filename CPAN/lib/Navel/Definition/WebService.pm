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
        @_
    );
}

sub merge {
   shift->SUPER::merge(
        \&web_service_definition_validator,
        @_ 
   );
}

sub original_properties {
    shift->SUPER::original_properties(\@RUNTIME_PROPERTIES);
}

sub url {
    my $self = shift;

    my $url = Mojo::URL->new()->scheme(
        'http' . ($self->{tls} ? 's' : '')
    )->host(
        $self->{interface_mask}
    )->port(
        $self->{port}
    );

    $url->query(ca => $self->{ca}) if (defined $self->{ca});
    $url->query(cert => $self->{cert}) if (defined $self->{cert});
    $url->query(ciphers => $self->{ciphers}) if (defined $self->{ciphers});
    $url->query(key => $self->{key}) if (defined $self->{key});
    $url->query(verify => $self->{verify}) if (defined $self->{verify});

    $url;
}

BEGIN {
    __PACKAGE__->create_setters(qw/
        interface_mask
        port
        tls
        ca
        cert
        ciphers
        key
        verify
    /);
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
