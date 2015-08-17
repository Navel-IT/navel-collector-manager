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
        __definition_package => $definition_package,
        __do_not_need_at_least_one => $do_not_need_at_least_one,
        __raw => [],
        __definitions => []
    }, ref $class || $class;
}

sub read {
    my $self = shift;

    $self->__set_raw($self->SUPER::read(shift));
}

sub write {
    my $self = shift;

    $self->SUPER::write(
        shift,
        [
            map {
                $_->get_original_properties()
            } @{$self->get_definitions()}
        ]
    );

    $self;
}

sub make_definition {
    my ($self, $raw_definition) = @_;

    my $definition = eval {
        my $definition_package = $self->get_definition_package();

        $definition_package->new($raw_definition);
    };

    $@ ? croak($self->get_definition_package() . ' : ' . $@) : $definition;
};

sub make {
    my ($self, $extra_parameters) = @_;

    if (eval 'require ' . $self->get_definition_package()) {
        if (reftype($self->get_raw()) eq 'ARRAY' and @{$self->get_raw()} || $self->get_do_not_need_at_least_one()) {
            my (@definitions, @names);

            for (@{$self->get_raw()}) {
                my $definition = $self->make_definition(reftype($extra_parameters) eq 'HASH' ? { %{$_}, %{$extra_parameters} } : $_);

                push @definitions, $definition;

                push @names, $definition->get_name();
            }

            @names == uniq(@names) ? $self->__set_definitions(\@definitions) : croak($self->get_definition_package() . ' : duplicate definition detected');
        } else {
            croak($self->get_definition_package() . ' : raw datas need to exists and to be encapsulated in an array');
        }
    } else {
        croak($self->get_definition_package() . ' : require failed');
    }

    $self;
}

sub get_definition_package {
    shift->{__definition_package};
}

sub get_do_not_need_at_least_one {
    shift->{__do_not_need_at_least_one};
}

sub get_raw {
    shift->{__raw};
}

sub __set_raw {
    my ($self, $value) = @_;

    $self->{__raw} = $value;

    $self;
}

sub get_definitions {
    shift->{__definitions};
}

sub __set_definitions {
    my ($self, $value) = @_;

    $self->{__definitions} = $value;

    $self;
}

sub __get_all_by_getter {
    my ($self, $getter_name) = @_;

    [ map { $_->$getter_name() } @{$self->get_definitions()} ];
}

sub get_names {
    shift->__get_all_by_getter('get_name');
}

sub get_by_name {
    my ($self, $definition_name) = @_;

    for (@{$self->get_definitions()}) {
        return $_ if ($_->get_name() eq $definition_name);
    }

    undef;
}

sub get_properties_by_name {
    my $definition = shift->get_by_name(shift);

    defined $definition ? $definition->get_properties() : undef;
}

sub add_definition {
    my ($self, $raw_definition) = @_;

    my $definition = $self->make_definition($raw_definition);

    unless (defined $self->get_by_name($definition->get_name())) {
        push @{$self->get_definitions()}, $definition;
    } else {
        croak($self->get_definition_package() . ' : duplicate definition detected');
    }

    $definition;
}

sub delete_definition {
    my ($self, $definition_name) = @_;

    my $definitions = $self->get_definitions();

    my $definition_to_delete_index = 0;

    my $finded;

    $definition_to_delete_index++ until ($finded = $definitions->[$definition_to_delete_index]->get_name() eq $definition_name);

    if ($finded) {
        splice @{$definitions}, $definition_to_delete_index, 1;
    } else {
        croak($self->get_definition_package() . ' : definition ' . $definition_name . ' does not exists');
    }

    $definition_name;
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
