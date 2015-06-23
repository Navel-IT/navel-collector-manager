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

use Carp qw/
    carp
    croak
/;

use String::Util qw/
    hascontent
/;

use Scalar::Util::Numeric qw/
    isint
/;

use Navel::Definition::Connector qw/
    :all
/;

use Navel::Utils qw/
    :all
/;

our $VERSION = 0.1;

#-> methods

sub to($$) {
    my ($connector, $datas) = @_;

    if (ref $connector eq 'Navel::Definition::Connector') {
        $connector = unblessed($connector);

        publicize($connector);
    }

    encode_json(
        {
            connector => $connector,
            time => time,
            datas => $datas
        }
    );
}

sub from($) {
    my $serialized = shift;

    my $datas = decode_json($serialized);

    if (reftype($datas) && isint($datas->{time}) && exists $datas->{datas}) {
        my $connector;

        if (defined $datas->{connector}) {
            croak('some datas are incorrects : connector definition is incorrect') unless (connector_definition_validator($datas->{connector}));

            $connector = Navel::Definition::Connector->new($datas->{connector});
        }

        return {
            connector => $connector,
            datas => $datas->{datas}
        };
    }

    croak('some datas are incorrects');
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
