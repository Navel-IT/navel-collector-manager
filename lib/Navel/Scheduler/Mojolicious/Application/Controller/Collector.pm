# Copyright 2015 Navel-IT
# navel-scheduler is developed by Yoann Le Garff, Nicolas Boquet and Yann Le Bras under GNU GPL v3

#-> BEGIN

#-> initialization

package Navel::Scheduler::Mojolicious::Application::Controller::Collector 0.1;

use Mojo::Base 'Mojolicious::Controller';

use Navel::Utils 'decode_json';

#-> methods

sub list_collector {
    my ($controller, $arguments, $callback) = @_;

    $controller->$callback(
        $controller->scheduler()->{core}->{collectors}->name(),
        200
    );
}

sub new_collector {
    my ($controller, $arguments, $callback) = @_;

    my (@ok, @ko);

    local $@;

    my $body = eval {
        decode_json($controller->req()->body());
    };

    unless ($@) {
        if (ref $body eq 'HASH') {
            return $controller->resource_already_exists(
                {
                    callback => $callback,
                    resource_name => $body->{name}
                }
            ) if defined $controller->scheduler()->{core}->{collectors}->definition_properties_by_name($body->{name});

            my $collector = eval {
                $controller->scheduler()->{core}->{collectors}->add_definition($body);
            };

            unless ($@) {
                $controller->scheduler()->{core}->register_collector_by_name($collector->{name});

                push @ok, 'adding and registering collector ' . $collector->{name} . '.';
            } else {
                push @ko, $@;
            }
        } else {
            push @ko, 'the request payload must represent a hash.';
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
        ),
        @ko ? 400 : 201
    );
}

sub show_collector {
    my ($controller, $arguments, $callback) = @_;

    my $collector = $controller->scheduler()->{core}->{collectors}->definition_properties_by_name($arguments->{collectorName});

    return $controller->resource_not_found(
        {
            callback => $callback,
            resource_name => $arguments->{collectorName}
        }
    ) unless defined $collector;

    $controller->$callback(
        $collector,
        200
    );
}

sub modify_collector {
    my ($controller, $arguments, $callback) = @_;

    my (@ok, @ko);

    local $@;

    my $body = eval {
        decode_json($controller->req()->body());
    };

    unless ($@) {
        if (ref $body eq 'HASH') {
            my $collector_definition = $controller->scheduler()->{core}->{collectors}->definition_by_name($arguments->{collectorName});

            return $controller->resource_not_found(
                {
                    callback => $callback,
                    resource_name => $arguments->{collectorName}
                }
            ) unless defined $collector_definition;

            delete $body->{name};

            my %before_modifications = (
                singleton => $collector_definition->{singleton},
                interval => $collector_definition->{scheduling}
            );

            my $errors = $collector_definition->merge($body);

            unless (@{$errors}) {
                $controller->scheduler()->{core}->job_by_type_and_name('collector', $collector_definition->{name})->new(
                    singleton => $collector_definition->{singleton},
                    interval => $collector_definition->{scheduling}
                ) unless $collector_definition->{singleton} == $before_modifications{singleton} && $collector_definition->{scheduling} == $before_modifications{interval};

                push @ok, 'modifying collector ' . $collector_definition->{name} . '.';
            } else {
                push @ko, 'error(s) occurred while modifying collector ' . $collector_definition->{name} . ':', $errors;
            }
        } else {
            push @ko, 'the request payload must represent a hash.';
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
        ),
        @ko ? 400 : 200
    );
}

sub delete_collector {
    my ($controller, $arguments, $callback) = @_;

    return $controller->resource_not_found(
        {
            callback => $callback,
            resource_name => $arguments->{collectorName}
        }
    ) unless $controller->scheduler()->{core}->unregister_job_by_type_and_name('collector', $arguments->{collectorName});

    my (@ok, @ko);

    local $@;

    eval {
        $controller->scheduler()->{core}->{collectors}->delete_definition(
            definition_name => $arguments->{collectorName}
        );
    };

    unless ($@) {
        push @ok, 'unregistering and deleting collector ' . $arguments->{collectorName} . '.';
    } else {
        push @ko, $@;
    }

    $controller->$callback(
        $controller->ok_ko(
            {
                ok => \@ok,
                ko => \@ko
            }
        ),
        @ko ? 400 : 200
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

Navel::Scheduler::Mojolicious::Application::Controller::Collector

=head1 AUTHOR

Yoann Le Garff, Nicolas Boquet and Yann Le Bras

=head1 LICENSE

GNU GPL v3

=cut

