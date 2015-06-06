# Copyright 2015 Navel-IT
# Navel Scheduler is developped by Yoann Le Garff, Nicolas Boquet and Yann Le Bras under GNU GPL v3

#-> BEGIN

#-> initialization

package Navel::Utils;

use strict;
use warnings;

use parent qw/
    Scalar::Util
/;

use subs qw/
    substitute_all_keys
/;

use Exporter::Easy (
    OK => [qw/
        :all
        blessed
        reftype
        get_a_proper_localtime
        replace_key
        substitute_all_keys
        publicize
        privasize
        unblessed
        encode_json
        decode_json
    /],
    TAGS => [
        all => [qw/
            blessed
            reftype
            get_a_proper_localtime
            replace_key
            substitute_all_keys
            publicize
            privasize
            unblessed
            encode_json
            decode_json
        /]
    ]
);

use JSON qw/
    encode_json
    decode_json
/;

our $VERSION = 0.1;

#-> functions

sub blessed($) {
   my $blessed = Scalar::Util::blessed(shift);

   return defined $blessed ? $blessed : '';
}

sub reftype($) {
   my $reftype = Scalar::Util::reftype(shift);

   return defined $reftype ? $reftype : '';
}

sub get_a_proper_localtime($) {
    my ($sec, $min, $hour, $mday, $mon, $year) = localtime shift;

    return sprintf '%d/%02d/%02d %02d:%02d:%02d', 1900 + $year, $mday, $mon, $hour, $min, $sec;
}

sub replace_key($$$) {
    my ($hash, $key, $new_key) = @_;

    $hash->{$new_key} = delete $hash->{$key};

    return 1;
}

sub substitute_all_keys($$$@) {
    my ($hash, $old, $new, $recursive) = @_;

    for (keys %{$hash}) {
        my $new_key = $_;

        my $a = $recursive && reftype($hash->{$_}) eq 'HASH';

        eval '$new_key =~ s/' . $old . '/' . $new . '/g';

        $@ ? return 0 : replace_key($hash, $_, $new_key);

        if ($recursive && reftype($hash->{$new_key}) eq 'HASH') {
            substitute_all_keys($hash->{$new_key}, $old, $new, $recursive) || return 0;
        }
    }

    return 1;
}

sub privasize($@) {
    return substitute_all_keys(shift, '^(.*)', '__$1', shift);
}

sub publicize($@) {
    return substitute_all_keys(shift, '^__', '', shift);
}

sub unblessed($) {
    return { %{+shift} };
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
