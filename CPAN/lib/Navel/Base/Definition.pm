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
    unblessed
/;

our $VERSION = 0.1;

#-> methods

sub new {
    my ($class, $validator, $parameters) = @_;

    croak('definition is invalid') unless ($validator->($parameters));

    bless dclone($parameters), ref $class || $class;
}

sub properties {
    unblessed(shift);
}

sub original_properties {
    my ($properties, $runtime_properties) = (shift->properties(), shift);

    delete $properties->{$_} for (@{$runtime_properties});

    $properties;
}

sub merge {
    my ($self, $validator, $properties_values) = @_;

    if ($validator->(
        {
            %{$self->properties()},
            %{$properties_values}
        }
    )) {
        while (my ($property, $value) = each %{$properties_values}) {
            $self->{$property} = $value;
        }

        1;
    }
}

BEGIN {
    sub create_setters {
        my $class = shift;

        no strict 'refs';

        $class = ref $class || $class;

        for my $property (@_) {
            *{$class . '::set_' . $property} = sub {
                shift->merge(
                    {
                        $property => shift
                    }
                );
            };
        }
    }

    __PACKAGE__->create_setters('name');
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
