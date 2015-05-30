# Copyright 2015 Navel-IT
# Navel Scheduler is developped by Yoann Le Garff, Nicolas Boquet and Yann Le Bras under GNU GPL v3

#-> BEGIN

#-> initialization

package Navel::Base::Definition::Etc::Parser;

use strict;
use warnings;

use parent qw/
    Navel::Base
    Navel::Base::Definition::Etc::Parser::Loader
/;

use List::MoreUtils qw/
    uniq
/;

use Navel::Utils qw/
    :all
/;

our $VERSION = 0.1;

#-> methods

sub new {
    my $class = shift;

    return bless {
        __raw => [],
        __definitions => []
    }, ref $class || $class;
}

sub load {
    my ($self, $file_path) = @_;

    my $return = $self->SUPER::load($file_path);

    $self->__set_raw($return->[1]) if ($return->[0]);

    return $return;
}

sub make {
    my ($self, $definition_package, $do_not_need_at_least_one, $extra_parameters) = @_;

    if (eval 'require ' . $definition_package) {
        if (reftype($self->get_raw()) eq 'ARRAY' and @{$self->get_raw()} || $do_not_need_at_least_one) {
            my (@definitions, @names);

            for my $parameters (@{$self->get_raw()}) {
                my $connector = eval {
                    $definition_package->new(reftype($extra_parameters) eq 'HASH' ? { %{$parameters}, %{$extra_parameters} } : $parameters);
                };

                unless ($@) {
                    push @definitions, $connector;

                    push @names, $connector->get_name();
                } else {
                    return [0, $definition_package . ' : one or more definitions are invalids'];
                }
            }

            if (@names == uniq(@names)) {
                $self->__set_definitions(\@definitions);

                return [1, undef];
            } else {
                return [0, $definition_package . ' : duplicate definition detected']
            }
        } else {
            return [0, $definition_package . ' : raw datas need to exists and to be encapsulated in an array'];
        }
    } else {
        return [0, $definition_package . ' : require failed'];
    }
}

sub get_raw {
    return shift->{__raw};
}

sub __set_raw {
    my ($self, $value) = @_;

    $self->{__raw} = $value;

    return $self;
}

sub get_definitions {
    return shift->{__definitions};
}

sub __set_definitions {
    my ($self, $value) = @_;

    $self->{__definitions} = $value;

    return $self;
}

sub __get_all_by_getter {
    my ($self, $getter_name) = @_;

    return [ map { $_->$getter_name() } @{$self->get_definitions()} ];
}

sub get_names {
    return shift->__get_all_by_getter('get_name');
}

sub get_properties_by_name {
    my ($self, $name) = @_;

    for (@{$self->get_definitions()}) {
        return $_->get_properties() if ($_->get_name() eq $name);
    }

    return undef;
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
