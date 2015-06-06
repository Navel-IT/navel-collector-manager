# Copyright 2015 Navel-IT
# Navel Scheduler is developped by Yoann Le Garff, Nicolas Boquet and Yann Le Bras under GNU GPL v3

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

    $connector = unblessed($connector);

    publicize($connector);

    my $json = encode_json(
        {
            connector => $connector,
            time => time,
            datas => $datas
        }
    );

    return [1, $json];
}

sub from($) {
    my $json = shift;

    my $datas = eval {
        decode_json($json);
    };

    unless ($@) {
        if (reftype($datas) eq 'HASH' && connector_definition_validator($datas->{connector}) && isint($datas->{time}) && exists $datas->{datas}) {
            return [
                1,
                {
                    connector => Navel::Definition::Connector->new(
                        $datas->{connector}
                    ),
                    datas => $datas->{datas}
                }
            ];
        }
    }

    return [0, 'Some datas are incorrects'];
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
