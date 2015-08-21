# Copyright 2015 Navel-IT
# Navel Scheduler is developed by Yoann Le Garff, Nicolas Boquet and Yann Le Bras under GNU GPL v3

#-> BEGIN

#-> initialization

package Navel::Base::Definition::Parser;

use strict;
use warnings;

use parent qw/
    Navel::Base
    Navel::Base::Definition::Parser::Reader
    Navel::Base::Definition::Parser::Writer
/;

use Carp 'croak';

use Scalar::Util::Numeric 'isint';

use Navel::Utils 'reftype';

our $VERSION = 0.1;

#-> methods

sub new {
    my ($class, $definition_package, $do_not_need_at_least_one, $maximum) = @_;

    my $self = bless {
        definition_package => $definition_package,
        do_not_need_at_least_one => $do_not_need_at_least_one,
        raw => [],
        definitions => []
    }, ref $class || $class;

    $self->set_maximum($maximum);
}

sub read {
    my $self = shift;

    $self->{raw} = $self->SUPER::read(shift);

    $self;
}

sub write {
    my $self = shift;

    $self->SUPER::write(
        shift,
        [
            map {
                $_->original_properties()
            } @{$self->{definitions}}
        ]
    );

    $self;
}

sub make_definition {
    my ($self, $raw_definition) = @_;

    my $definition = eval {
        $self->{definition_package}->new($raw_definition);
    };

    $@ ? croak($self->{definition_package} . ' : ' . $@) : $definition;
};

sub make {
    my ($self, $extra_parameters) = @_;

    if (eval 'require ' . $self->{definition_package}) {
        if (reftype($self->{raw}) eq 'ARRAY' and @{$self->{raw}} || $self->{do_not_need_at_least_one}) {
            $self->add_definition(reftype($extra_parameters) eq 'HASH' ? { %{$_}, %{$extra_parameters} } : $_) for (@{$self->{raw}});
        } else {
            croak($self->{definition_package} . ' : raw datas need to exists and to be encapsulated in an array');
        }
    } else {
        croak($self->{definition_package} . ' : require failed');
    }

    $self;
}

sub set_maximum {
    my ($self, $maximum) = @_;

    $maximum = $maximum || 0;

    croak('maximum must be an integer equal or greater than 0') unless (isint($maximum) && $maximum >= 0);

    $self->{maximum} = $maximum;

    $self;
}

sub definition_by_name {
    my ($self, $definition_name) = @_;

    croak('definition_name must be defined') unless (defined $definition_name);

    for (@{$self->{definitions}}) {
        return $_ if ($_->{name} eq $definition_name);
    }

    undef;
}

sub definition_properties_by_name {
    my $definition = shift->definition_by_name(shift);

    defined $definition ? $definition->properties() : undef;
}

sub all_by_property_name {
    my ($self, $property_name) = @_;

    croak('property_name must be defined') unless (defined $property_name);

    [
        map {
            $_->can($property_name) ? $_->$property_name() : $_->{$property_name}
        } @{$self->{definitions}}
    ];
}

sub add_definition {
    my ($self, $raw_definition) = @_;

    my $definition = $self->make_definition($raw_definition);

    croak($self->{definition_package} . ' : the maximum number of definition (' . $self->{maximum} . ') has been reached') if ($self->{maximum} && @{$self->{definitions}} > $self->{maximum});
    croak($self->{definition_package} . ' : duplicate definition detected') if (defined $self->definition_by_name($definition->{name}));

    push @{$self->{definitions}}, $definition;

    $definition;
}

sub delete_definition {
    my ($self, $definition_name, $do_before_slice) = @_;

    croak('definition_name must be defined') unless (defined $definition_name);

    my $definition_to_delete_index = 0;

    my $finded;

    $definition_to_delete_index++ until ($finded = $self->{definitions}->[$definition_to_delete_index]->{name} eq $definition_name);

    croak($self->{definition_package} . ' : definition ' . $definition_name . ' does not exists') unless ($finded);

    $do_before_slice->($self->{definitions}->[$definition_to_delete_index]) if (ref $do_before_slice eq 'CODE');

    splice @{$self->{definitions}}, $definition_to_delete_index, 1;

    $definition_name;
}

BEGIN {
    sub create_getters {
        my $class = shift;

        no strict 'refs';

        $class = ref $class || $class;

        for my $property (@_) {
            *{$class . '::' . $property} = sub {
                shift->all_by_property_name($property);
            };
        }
    }

    __PACKAGE__->create_getters('name');
}

# sub AUTOLOAD {}

# sub DESTROY {}

1;

#-> END

__END__

=pod

=head1 NAME

Navel::Base::Definition::Parser

=head1 AUTHOR

Yoann Le Garff, Nicolas Boquet and Yann Le Bras

=head1 LICENSE

GNU GPL v3

=cut
