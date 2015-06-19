# Copyright 2015 Navel-IT
# Navel Scheduler is developed by Yoann Le Garff, Nicolas Boquet and Yann Le Bras under GNU GPL v3

#-> BEGIN

#-> initialization

package Navel::Base::Definition;

use strict;
use warnings;

use parent qw/
    Navel::Base
/;

use Carp qw/
    carp
    croak
/;

use Storable qw/
    dclone
/;

use Navel::Utils qw/
    :all
/;

our $VERSION = 0.1;

#-> methods

sub new {
    my ($class, $validator, $parameters) = @_;

    if ($validator->($parameters)) {
        my $self = dclone($parameters);

        privasize($self);

        $class = ref $class || $class;

        return bless $self, $class;
    }

    croak('Definition is invalid');
}

sub set_generic {
    my ($self, $validator, $property, $value) = @_;

    $self = $self->new(
        $validator,
        {
            %{$self->get_properties()},
            %{{
                $property => $value
            }}
        }
    );

    return $self;
}

sub get_properties {
    my $self_copy = unblessed(shift);

    publicize($self_copy);

    return $self_copy;
}

sub get_original_properties {
    my ($self_copy, $original_properties) = (shift->get_properties(), shift);

    exists $self_copy->{$_} || delete $self_copy->{$_} for (keys %{$original_properties});

    return $self_copy;
}

sub get_name {
    return shift->{__name};
}

sub set_name {
    return shift->set_generic('name', shift);
}

# sub AUTOLOAD {}

# sub DESTROY {}

1;

#-> END

__END__

=pod

=head1 NAME

Navel::Base::Definition

=head1 AUTHOR

Yoann Le Garff, Nicolas Boquet and Yann Le Bras

=head1 LICENSE

GNU GPL v3

=cut
