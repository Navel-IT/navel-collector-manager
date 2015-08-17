# Copyright 2015 Navel-IT
# Navel Scheduler is developed by Yoann Le Garff, Nicolas Boquet and Yann Le Bras under GNU GPL v3

#-> BEGIN

#-> initialization

package Navel::Utils;

use strict;
use warnings;

use subs 'substitute_all_keys';

use Exporter::Easy (
    OK => [qw/
        :all
        blessed
        reftype
        human_readable_localtime
        replace_key
        substitute_all_keys
        publicize
        privasize
        unblessed
        encode_json
        decode_json
        encode_json_pretty
        encode_sereal_constructor
        decode_sereal_constructor
    /],
    TAGS => [
        all => [qw/
            blessed
            reftype
            human_readable_localtime
            replace_key
            substitute_all_keys
            publicize
            privasize
            unblessed
            encode_json
            decode_json
            encode_json_pretty
            encode_sereal_constructor
            decode_sereal_constructor
        /]
    ]
);

require Scalar::Util;

use JSON qw/
    encode_json
    decode_json
/;

use Sereal;

our $VERSION = 0.1;

#-> functions

sub blessed($) {
   my $blessed = Scalar::Util::blessed(shift);

   defined $blessed ? $blessed : '';
}

sub reftype($) {
   my $reftype = Scalar::Util::reftype(shift);

   defined $reftype ? $reftype : '';
}

sub human_readable_localtime($) {
    my ($sec, $min, $hour, $mday, $mon, $year) = localtime shift;

    sprintf '%d/%02d/%02d %02d:%02d:%02d', 1900 + $year, $mday, $mon, $hour, $min, $sec;
}

sub replace_key($$$) {
    my ($hash, $key, $new_key) = @_;

    $hash->{$new_key} = delete $hash->{$key};
}

sub substitute_all_keys($$$@) {
    my ($hash, $old, $new, $recursive) = @_;

    local $@;

    for (keys %{$hash}) {
        my $new_key = $_;

        eval '$new_key =~ s/' . $old . '/' . $new . '/g';

        $@ ? return 0 : replace_key($hash, $_, $new_key);

        if ($recursive && reftype($hash->{$new_key}) eq 'HASH') {
            substitute_all_keys($hash->{$new_key}, $old, $new, $recursive) || return 0;
        }
    }
}

sub privasize($@) {
    substitute_all_keys(shift, '^(.*)', '__$1', shift);
}

sub publicize($@) {
    substitute_all_keys(shift, '^__', '', shift);
}

sub unblessed($) {
    return { %{+shift} };
}

sub encode_json_pretty($) {
    JSON->new()->utf8()->pretty()->encode(shift);
}

sub encode_sereal_constructor {
    Sereal::Encoder->new();
}

sub decode_sereal_constructor {
    Sereal::Decoder->new();
}

1;

#-> END

__END__

=pod

=head1 NAME

Navel::Utils

=head1 AUTHOR

Yoann Le Garff, Nicolas Boquet and Yann Le Bras

=head1 LICENSE

GNU GPL v3

=cut
