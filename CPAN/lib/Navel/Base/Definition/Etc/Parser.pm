# Copyright 2015 Navel-IT
# Navel Scheduler is developed by Yoann Le Garff, Nicolas Boquet and Yann Le Bras under GNU GPL v3

#-> BEGIN

#-> initialization

package Navel::Base::Definition::Etc::Parser;

use strict;
use warnings;

use parent qw/
    Navel::Base
    Navel::Base::Definition::Etc::Parser::Reader
    Navel::Base::Definition::Etc::Parser::Writer
/;

use Carp 'croak';

use List::MoreUtils 'uniq';

use Navel::Utils 'reftype';

our $VERSION = 0.1;

#-> methods

sub new {
    my ($class, $definition_package, $do_not_need_at_least_one) = @_;

    bless {
        definition_package => $definition_package,
        do_not_need_at_least_one => $do_not_need_at_least_one,
        raw => [],
        definitions => []
    }, ref $class || $class;
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
        my $definition_package = $self->{definition_package};

        $definition_package->new($raw_definition);
    };

    $@ ? croak($self->{definition_package} . ' : ' . $@) : $definition;
};

sub make {
    my ($self, $extra_parameters) = @_;

    if (eval 'require ' . $self->{definition_package}) {
        if (reftype($self->{raw}) eq 'ARRAY' and @{$self->{raw}} || $self->{do_not_need_at_least_one}) {
            my (@definitions, @names);

            for (@{$self->{raw}}) {
                my $definition = $self->make_definition(reftype($extra_parameters) eq 'HASH' ? { %{$_}, %{$extra_parameters} } : $_);

                push @definitions, $definition;

                push @names, $definition->{name};
            }

            @names == uniq(@names) ? $self->{definitions} = \@definitions : croak($self->{definition_package} . ' : duplicate definition detected');
        } else {
            croak($self->{definition_package} . ' : raw datas need to exists and to be encapsulated in an array');
        }
    } else {
        croak($self->{definition_package} . ' : require failed');
    }

    $self;
}

sub definition_by_name {
    my ($self, $definition_name) = @_;

    for (@{$self->{definitions}}) {
        return $_ if ($_->{name} eq $definition_name);
    }

    undef;
}

sub definition_properties_by_name {
    my $definition = shift->definition_by_name(shift);

    defined $definition ? $definition->properties() : undef;
}

sub add_definition {
    my ($self, $raw_definition) = @_;

    my $definition = $self->make_definition($raw_definition);

    unless (defined $self->definition_by_name($definition->{name})) {
        push @{$self->{definitions}}, $definition;
    } else {
        croak($self->{definition_package} . ' : duplicate definition detected');
    }

    $definition;
}

sub delete_definition {
    my ($self, $definition_name) = @_;

    my $definitions = $self->{definitions};

    my $definition_to_delete_index = 0;

    my $finded;

    $definition_to_delete_index++ until ($finded = $definitions->[$definition_to_delete_index]->{name} eq $definition_name);

    if ($finded) {
        splice @{$definitions}, $definition_to_delete_index, 1;
    } else {
        croak($self->{definition_package} . ' : definition ' . $definition_name . ' does not exists');
    }

    $definition_name;
}

sub all_by_property_name {
    my ($self, $property_name) = @_;

    [
        map {
            $_->can($property_name) ? $_->$property_name() : $_->{$property_name}
        } @{$self->{definitions}}
    ];
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

Navel::Base::Definition::Etc::Parser

=head1 AUTHOR

Yoann Le Garff, Nicolas Boquet and Yann Le Bras

=head1 LICENSE

GNU GPL v3

=cut
