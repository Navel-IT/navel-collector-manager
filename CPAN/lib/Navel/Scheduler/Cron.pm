# Copyright 2015 Navel-IT
# Navel Scheduler is developped by Yoann Le Garff, Nicolas Boquet and Yann Le Bras under GNU GPL v3

#-> BEGIN

#-> initialization

package Navel::Scheduler::Cron;

use strict;
use warnings;

use parent qw/
    Navel::Base
/;

use Carp qw/
    carp
    croak
/;

use AnyEvent::DateTime::Cron;

use Navel::Scheduler::Cron::Exec;

use Navel::Scheduler::Cron::Fork;

use Navel::RabbitMQ::Publisher;

use Navel::RabbitMQ::Serialize::Data qw/
    to
/;

use Navel::Utils qw/
    :all
/;

our $VERSION = 0.1;

#-> methods

sub new {
    my ($class, $connectors, $rabbitmq, $logger) = @_;

    if (blessed($connectors) eq 'Navel::Definition::Connector::Etc::Parser' && blessed($rabbitmq) eq 'Navel::Definition::RabbitMQ::Etc::Parser' && blessed($logger) eq 'Navel::Logger') {
        my $self = {
            __connectors => $connectors,
            __rabbitmq => $rabbitmq,
            __publishers => [],
            __buffers => {},
            __logger => $logger,
            __cron => AnyEvent::DateTime::Cron->new(
                quartz => 1
            )
        };

        $class = ref $class || $class;

        return bless $self, $class;
    }

    croak('Object(s) invalid(s).');
}

sub register_connectors {
    my $self = shift;

    for my $connector (@{$self->get_connectors()->get_definitions()}) {
        $self->get_cron()->add($connector->get_scheduling(),
            name => 'connector_' . $connector->get_name(),
            single => 1,
            sub {
                if ($connector->is_type_code()) {
                    Navel::Scheduler::Cron::Fork->new(
                        $connector,
                        $self->get_logger()
                    )->when_done(
                        sub {
                            my $datas = shift;

                            my $generic_message = 'Get and serialize datas for connector ' . $connector->get_name();

                            if (defined $datas) {
                                $self->get_logger()->push_to_buffer('Raw datas returned by connector ' . $connector->get_name() . ' : ' . $datas . '.', 'debug');
                            } else {
                                $self->get_logger()->push_to_buffer('Raw datas returned by connector ' . $connector->get_name() . ' : raw datas are undefined.', 'debug');
                            }

                            $self->get_logger()->flush_buffer(1);

                            my $serialize = to(
                                $connector,
                                $datas
                            );

                            if ($serialize->[0]) {
                                $self->get_logger()->good($generic_message . '.', 'info')->flush_buffer(1);

                                map { $_->push_in_buffer($serialize->[1]) } @{$self->get_publishers()};
                            } else {
                                $self->get_logger()->bad($generic_message . ' failed.', 'err')->flush_buffer(1);
                            }
                        }
                    );
                } else {
                    my $body = Navel::Scheduler::Cron::Exec->new(
                        $connector,
                        $self->get_logger()
                    )->exec()->serialize();

                    map { $_->push_in_buffer($body) } @{$self->get_publishers()};
                }
            }
        );
    }

    return $self;
}

sub init_publishers {
    my $self = shift;

    for my $rabbitmq (@{$self->get_rabbitmq()->get_definitions()}) {
        $self->get_logger()->push_to_buffer('Initialize publisher ' . $rabbitmq->get_name() . '.', 'info')->flush_buffer(1);

        push @{$self->get_publishers()}, Navel::RabbitMQ::Publisher->new($rabbitmq);
    }

    return $self;
}

sub connect_publishers {
    my $self = shift;

    for my $publisher (@{$self->get_publishers()}) {
        my $publisher_generic_message = 'Connect publisher ' . $publisher->get_definition()->get_name();

        unless ($publisher->get_net()->is_connected()) {
            my $connect_message = $publisher->connect();

            if ($connect_message) {
                $self->get_logger()->bad($publisher_generic_message . ' : ' . $connect_message . '.', 'warn')->flush_buffer(1);
            } else {
                $self->get_logger()->good($publisher_generic_message . '.', 'notice')->flush_buffer(1);
            }
        } else {
            $self->get_logger()->bad($publisher_generic_message . ' : seem already connected.', 'notice')->flush_buffer(1);
        }
    }

    return $self;
}

sub register_publishers {
    my $self = shift;

    my $channel_id = 1;

    for my $publisher (@{$self->get_publishers()}) {
        $self->get_cron()->add($publisher->get_definition()->get_scheduling(),
            name => 'publisher_' . $publisher->get_definition()->get_name(),
            single => 1,
            sub {
                my $publish_generic_message = 'Publish datas for publisher ' . $publisher->get_definition()->get_name() . ' on channel ' . $channel_id;

                if ($publisher->get_net()->is_connected()) {
                    my @buffer = @{$publisher->get_buffer()};

                    if (@buffer) {
                        $self->get_logger()->push_to_buffer('Clear buffer for publisher ' . $publisher->get_definition()->get_name() . '.', 'notice')->flush_buffer(1);

                        $publisher->clear_buffer();

                        eval {
                            $publisher->get_net()->channel_open($channel_id);

                            for my $body (@buffer) {
                                $self->get_logger()->push_to_buffer($publish_generic_message . ' : send body.', 'info')->flush_buffer(1);

                                $publisher->get_net()->publish($channel_id, $publisher->get_definition()->get_routing_key(), $body,
                                    {
                                        exchange => $publisher->get_definition()->get_exchange()
                                    }
                                );
                            }

                            $publisher->get_net()->channel_close($channel_id);
                        };

                        if ($@) {
                            $self->get_logger()->bad($publish_generic_message . ' : ' . $@ . '.', 'warn')->flush_buffer(1);
                        } else {
                            $self->get_logger()->good($publish_generic_message . '.', 'notice')->flush_buffer(1);
                        }
                    } else {
                        $self->get_logger()->bad('Buffer for publisher ' . $publisher->get_definition()->get_name() . ' is empty.', 'info')->flush_buffer(1);
                    }
                } else {
                    $self->get_logger()->bad($publish_generic_message . ' : publisher is not connected.', 'warn')->flush_buffer(1);
                }
            }
        );
    }

    return $self;
}

sub disconnect_publishers {
    my $self = shift;

    for (@{$self->get_publishers()}) {
        my $disconnect_generic_message = 'Disconnect publisher ' . $_->get_definition()->get_name();

        if (my $error = $_->disconnect()) {
            $self->get_logger()->good($disconnect_generic_message . ' : ' . $error . '.', 'notice')->flush_buffer(1);
        } else {
            $self->get_logger()->good($disconnect_generic_message . '.', 'notice')->flush_buffer(1);
        }
    }

    return $self;
}

sub start {
    my $self = shift;

    $self->get_cron()->start()->recv();

    return $self;
}

sub stop {
    my $self = shift;

    $self->get_cron()->stop();

    return $self;
}

sub get_connectors {
    return shift->{__connectors};
}

sub get_rabbitmq {
    return shift->{__rabbitmq};
}

sub get_publishers {
    return shift->{__publishers};
}

sub get_publisher_by_definition_name {
    my ($self, $name) = @_;

    for (@{$self->get_publishers()}) {
        return $_ if ($_->get_definition()->get_name() eq $name);
    }

    return undef;
}

sub get_buffers {
    return shift->{__buffers};
}

sub get_logger {
    return shift->{__logger};
}

sub get_cron {
    return shift->{__cron};
}

# sub AUTOLOAD {}

# sub DESTROY {}

1;

#-> END

__END__

=pod

=head1 NAME

Navel::Scheduler::Cron

=head1 AUTHOR

Yoann Le Garff, Nicolas Boquet and Yann Le Bras

=head1 LICENSE

GNU GPL v3

=cut
