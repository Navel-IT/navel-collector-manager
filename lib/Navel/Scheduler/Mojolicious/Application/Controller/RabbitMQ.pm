# Copyright 2015 Navel-IT
# navel-scheduler is developed by Yoann Le Garff, Nicolas Boquet and Yann Le Bras under GNU GPL v3

#-> BEGIN

#-> initialization

package Navel::Scheduler::Mojolicious::Application::Controller::RabbitMQ 0.1;

use Mojo::Base 'Mojolicious::Controller';

use Navel::Utils 'decode_json';

#-> methods

sub list_rabbitmq {
    my ($controller, $arguments, $callback) = @_;

    $controller->$callback(
        $controller->scheduler()->{core}->{rabbitmq}->name()
    );
}

sub new_rabbitmq {
    my ($controller, $arguments, $callback) = @_;

    my (@ok, @ko);

    my $body = eval {
        decode_json($controller->req()->body());
    };

    unless ($@) {
        if (ref $body eq 'HASH') {
            my $rabbitmq = eval {
                $controller->scheduler()->{core}->{rabbitmq}->add_definition($body);
            };

            unless ($@) {
                $controller->scheduler()->{core}->init_publisher_by_name($rabbitmq->{name})->register_publisher_by_name($rabbitmq->{name});

                push @ok, 'adding rabbitmq ' . $rabbitmq->{name} . ' and registering his publisher.';

                $controller->scheduler()->{core}->connect_publisher_by_name($rabbitmq->{name}) if $rabbitmq->{auto_connect};
            } else {
                push @ko, $@;
            }
        } else {
            push @ko, 'body need to represent a hashtable.';
        }
    } else {
        push @ko, $@;
    }

    $controller->$callback(
        $controller->ok_ko(
            {
                ok => \@ok,
                ko => \@ko
            }
        )
    );
}

sub show_rabbitmq {
    my ($controller, $arguments, $callback) = @_;

    $controller->$callback(
        $controller->scheduler()->{core}->{rabbitmq}->definition_properties_by_name($arguments->{rabbitmqName}) || {},
        200
    );
}

sub modify_rabbitmq {
    my ($controller, $arguments, $callback) = @_;

    my (@ok, @ko);

    my $body = eval {
        decode_json($controller->req()->body());
    };

    unless ($@) {
        if (ref $body eq 'HASH') {
            my $publisher = $controller->scheduler()->{core}->publisher_by_name($arguments->{rabbitmqName});

            if (defined $publisher) {
                delete $body->{name};

                my %before_modifications = (
                    connected => $publisher->is_connected() || $publisher->is_connecting(),
                    interval => $publisher->{definition}->{scheduling}
                );

                my $errors = $publisher->{definition}->merge($body);

                unless (@{$errors}) {
                    $controller->scheduler()->{core}->disconnect_publisher_by_name($publisher->{definition}->{name}) if $before_modifications{connected};

                    $controller->scheduler()->{core}->job_by_type_and_name('publisher', $publisher->{definition}->{name})->new(
                        interval => $publisher->{definition}->{scheduling}
                    ) unless $publisher->{definition}->{scheduling} == $before_modifications{interval};

                    push @ok, 'modifying rabbitmq ' . $publisher->{definition}->{name} . '.';
                } else {
                    push @ko, 'error(s) occurred while modifying rabbitmq ' . $publisher->{definition}->{name}, $errors;
                }
            } else {
                push @ko, 'rabbitmq ' . $arguments->{rabbitmqName} . " and his publisher don't exists.";
            }
        } else {
            push @ko, 'body need to represent a hashtable.';
        }
    } else {
        push @ko, $@;
    }

    $controller->$callback(
        $controller->ok_ko(
            {
                ok => \@ok,
                ko => \@ko
            }
        )
    );
}

sub delete_rabbitmq {
    my ($controller, $arguments, $callback) = @_;

    my (@ok, @ko);

    if ($controller->scheduler()->{core}->unregister_job_by_type_and_name('publisher', $arguments->{rabbitmqName})) {
        push @ok, 'unregistering publisher ' . $arguments->{rabbitmqName} . '.';

        eval {
            $controller->scheduler()->{core}->delete_publisher_and_definition_associated_by_name($arguments->{rabbitmqName});
        };

        unless ($@) {
            push @ok, 'deleting rabbitmq ' . $arguments->{rabbitmqName} . ' and his publisher.';
        } else {
            push @ko, $@;
        }
    } else {
        push @ko, 'rabbitmq ' . $arguments->{rabbitmqName} . " don't exists.";
    }

    $controller->$callback(
        $controller->ok_ko(
            {
                ok => \@ok,
                ko => \@ko
            }
        )
    );
}

# sub AUTOLOAD {}

# sub DESTROY {}

1;

#-> END

__END__

=pod

=encoding utf8

=head1 NAME

Navel::Scheduler::Mojolicious::Application::Controller::RabbitMQ

=head1 AUTHOR

Yoann Le Garff, Nicolas Boquet and Yann Le Bras

=head1 LICENSE

GNU GPL v3

=cut
