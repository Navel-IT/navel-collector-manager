# Copyright 2015 Navel-IT
# Navel Scheduler is developed by Yoann Le Garff, Nicolas Boquet and Yann Le Bras under GNU GPL v3

#-> BEGIN

#-> initialization

package Navel::Base::Definition;

use strict;
use warnings;

use parent 'Navel::Base';

use Carp 'croak';

use Storable 'dclone';

use Navel::Utils qw/
    privasize
    unblessed
    publicize
/;

our $VERSION = 0.1;

#-> methods

sub new {
    my ($class, $validator, $parameters) = @_;

    croak('definition is invalid') unless ($validator->($parameters));

    my $self = dclone($parameters);

    privasize($self);

    bless $self, ref $class || $class;
}

sub get_properties {
    my $self_copy = unblessed(shift);

    publicize($self_copy);

    $self_copy;
}

sub get_original_properties {
    my ($self_copy, $runtime_properties) = (shift->get_properties(), shift);

    delete $self_copy->{$_} for (@{$runtime_properties});

    $self_copy;
}

sub merge {
    my ($self, $validator, $properties_values) = @_;

    if ($validator->(
        {
            %{$self->get_properties()},
            %{$properties_values}
        }
    )) {
        while (my ($property, $value) = each %{$properties_values}) {
            $self->{'__' . $property} = $value;
        }

        1;
    }
}

sub get_name {
    shift->{__name};
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
