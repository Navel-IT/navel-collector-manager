# Copyright 2015 Navel-IT
# navel-scheduler is developed by Yoann Le Garff, Nicolas Boquet and Yann Le Bras under GNU GPL v3

#-> BEGIN

#-> initialization

package Navel::Scheduler::Parser 0.1;

use Navel::Base;

use parent qw/
    Navel::Base::Definition::Parser::Reader
    Navel::Base::Definition::Parser::Writer
/;

use Carp 'croak';

use Navel::Base::Definition;

use Navel::Utils ':numeric';

#-> methods

sub new {
    my $class = shift;

    bless {
        definition => {}
    }, ref $class || $class;
}

sub validate {
    my ($class, %options) = @_;

    croak('parameters must be a HASH reference') unless ref $options{parameters} eq 'HASH';

    Navel::Base::Definition->validate(
        parameters => $options{parameters},
        definition_class => __PACKAGE__,
        validator_struct => {
            collectors => {
                definitions_from_file => 'text',
                collectors_exec_directory => 'text',
                maximum => 'main_positive_integer',
                maximum_simultaneous_exec => 'main_positive_integer',
                execution_timeout => 'main_positive_integer'
            },
            publishers => {
                definitions_from_file => 'text',
                maximum => 'main_positive_integer',
                maximum_simultaneous_exec => 'main_positive_integer'
            },
            webservices => {
                definitions_from_file => 'text',
                credentials => {
                    login => 'text',
                    password => 'text'
                },
                mojo_server => 'main_mojo_server_properties'
            }
        },
        validator_types => {
            main_positive_integer => sub {
                my $value = shift;

                isint($value) && $value >= 0;
            },
            main_mojo_server_properties => sub {
                my $value = shift;

                my $customs_options_ok = 0;

                if (ref $value eq 'HASH') {
                    $customs_options_ok = 1;

                    my $properties_type = {
                        # Mojo::Server
                        reverse_proxy => \&isint,
                        # Mojo::Server::Daemon
                        backlog => \&isint,
                        inactivity_timeout => \&isint,
                        max_clients => \&isint,
                        max_requests => \&isint,
                        # Mojo::Server::Prefork
                        accepts => \&isint,
                        accept_interval => \&isfloat,
                        graceful_timeout => \&isfloat,
                        heartbeat_interval => \&isfloat,
                        heartbeat_timeout => \&isfloat,
                        multi_accept => \&isint,
                        workers => \&isint
                    };

                    while (my ($property, $type) = each %{$properties_type}) {
                        $customs_options_ok = 0 if exists $value->{$property} && ! $type->($value->{$property});
                    }
                }

                $customs_options_ok;
            }
        }
    );
}

sub set_definition {
    my ($self, $value) = @_;

    my $errors = $self->validate(
        parameters => $value
    );

    die $errors if @{$errors};

    $self->{definition} = $value;

    $self;
}

sub read {
    my $self = shift;

    $self->set_definition($self->SUPER::read(@_));

    $self;
}

sub write {
    my $self = shift;

    $self->SUPER::write(
        definitions => $self->{definition},
        @_
    );

    $self;
}

# sub AUTOLOAD {}

# sub DESTROY {}

1;

#-> END

__END__

=pod

=encoding utf8

=head1 NAME

Navel::Scheduler::Parser

=head1 AUTHOR

Yoann Le Garff, Nicolas Boquet and Yann Le Bras

=head1 LICENSE

GNU GPL v3

=cut
