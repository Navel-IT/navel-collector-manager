# Copyright 2015 Navel-IT
# Navel Scheduler is developed by Yoann Le Garff, Nicolas Boquet and Yann Le Bras under GNU GPL v3

#-> BEGIN

#-> initialization

package Navel::RabbitMQ::Serialize::Data;

use strict;
use warnings;

use Exporter::Easy (
    OK => [qw/
        $VERSION
        :all
        to
        from
    /],
    TAGS => [
        all => [qw/
            $VERSION
            to
            from
        /]
    ]
);

use Carp 'croak';

use Scalar::Util::Numeric 'isint';

use Navel::Definition::Connector ':all';
use Navel::Utils qw/
    blessed
    unblessed
    reftype
    encode_sereal_constructor
    decode_sereal_constructor
/;

our $VERSION = 0.1;

#-> functions

sub to($@) {
    my ($datas, $connector, $collection) = @_;

    $connector = unblessed($connector) if (blessed($connector) eq 'Navel::Definition::Connector');

    encode_sereal_constructor()->encode(
        {
            datas => $datas,
            time => time,
            connector => $connector,
            collection => defined $collection ? sprintf '%s', $collection : $collection
        }
    );
}

sub from($) {
    my $serialized = shift;

    my $deserialized = decode_sereal_constructor()->decode($serialized);

    croak('deserialized datas are invalid') unless (reftype($deserialized) && isint($deserialized->{time}) && exists $deserialized->{datas} && exists $deserialized->{collection});

    my $connector;

    if (defined $deserialized->{connector}) {
        croak('deserialized datas are invalid : connector definition is invalid') unless (connector_definition_validator($deserialized->{connector}));

        $connector = Navel::Definition::Connector->new($deserialized->{connector});
    }

    $deserialized->{collection} = sprintf '%s', $deserialized->{collection} if (defined $deserialized->{collection});

    {
        %{$deserialized},
        %{
            {
                connector => $connector
            }
        }
    };
}

# sub AUTOLOAD {}

# sub DESTROY {}

1;

#-> END

__END__

=pod

=head1 NAME

Navel::RabbitMQ::Serialize::Data

=head1 AUTHOR

Yoann Le Garff, Nicolas Boquet and Yann Le Bras

=head1 LICENSE

GNU GPL v3

=cut
