# Copyright (C) 2015 Yoann Le Garff, Nicolas Boquet and Yann Le Bras
# navel-scheduler is licensed under the Apache License, Version 2.0

#-> BEGIN

#-> initialization

package Navel::Scheduler::Mojolicious::Application::Controller::Swagger2::Publisher 0.1;

use Navel::Base;

use Mojo::Base 'Mojolicious::Controller';

use Promises 'collect';

#-> methods

sub list_publishers {
    my ($controller, $arguments, $callback) = @_;

    $controller->$callback(
        $controller->daemon()->{core}->{publishers}->all_by_property_name('name'),
        200
    );
}

sub new_publisher {
    my ($controller, $arguments, $callback) = @_;

    return $controller->resource_already_exists(
        {
            callback => $callback,
            resource_name => $arguments->{publisher}->{name}
        }
    ) if defined $controller->daemon()->{core}->{publishers}->definition_by_name($arguments->{publisher}->{name});

    my (@ok, @ko);

    local $@;

    my $publisher = eval {
        $controller->daemon()->{core}->{publishers}->add_definition($arguments->{publisher});
    };

    unless ($@) {
        $controller->daemon()->{core}->init_publisher_by_name($publisher->{name})->register_publisher_by_name($publisher->{name});

        push @ok, $publisher->full_name() . ' added.';
    } else {
        push @ko, $@;
    }

    $controller->$callback(
        $controller->ok_ko(\@ok, \@ko),
        @ko ? 400 : 201
    );
}

sub show_publisher {
    my ($controller, $arguments, $callback) = @_;

    my $publisher = $controller->daemon()->{core}->{publishers}->definition_properties_by_name($arguments->{publisherName});

    return $controller->resource_not_found(
        {
            callback => $callback,
            resource_name => $arguments->{publisherName}
        }
    ) unless defined $publisher;

    $controller->$callback(
        $publisher,
        200
    );
}

sub modify_publisher {
    my ($controller, $arguments, $callback) = @_;

    my $publisher = $controller->daemon()->{core}->{publishers}->definition_by_name($arguments->{publisherName});

    return $controller->resource_not_found(
        {
            callback => $callback,
            resource_name => $arguments->{publisherName}
        }
    ) unless defined $publisher;

    my (@ok, @ko);

    local $@;

    delete $arguments->{publisher}->{name};

    $arguments->{publisher} = {
        %{$publisher->properties()},
        %{$arguments->{publisher}}
    };

    eval {
        $controller->daemon()->{core}->delete_publisher_and_definition_associated_by_name($arguments->{publisher}->{name});
    };

    unless ($@) {
        my $publisher = eval {
            $controller->daemon()->{core}->{publishers}->add_definition($arguments->{publisher});
        };

        unless ($@) {
            $controller->daemon()->{core}->init_publisher_by_name($publisher->{name})->register_publisher_by_name($publisher->{name});

            push @ok, $publisher->full_name() . ' modified.';
        } else {
            push @ko, $@;
        }
    } else {
        push @ko, $@;
    }

    $controller->$callback(
        $controller->ok_ko(\@ok, \@ko),
        @ko ? 400 : 200
    );
}

sub delete_publisher {
    my ($controller, $arguments, $callback) = @_;

    my $publisher = $controller->daemon()->{core}->{publishers}->definition_by_name($arguments->{publisherName});

    return $controller->resource_not_found(
        {
            callback => $callback,
            resource_name => $arguments->{publisherName}
        }
    ) unless defined $publisher;

    my $publisher_full_name = $publisher->full_name();

    my (@ok, @ko);

    local $@;

    eval {
        $controller->daemon()->{core}->delete_publisher_and_definition_associated_by_name($publisher->{name});
    };

    unless ($@) {
        push @ok, $publisher_full_name . ': killed, unregistered and deleted.';
    } else {
        push @ko, $@;
    }

    $controller->$callback(
        $controller->ok_ko(\@ok, \@ko),
        @ko ? 400 : 200
    );
}

sub show_publisher_connection_status {
    my ($controller, $arguments, $callback) = @_;

    my $publisher = $controller->daemon()->{core}->{publishers}->definition_by_name($arguments->{publisherName});

    return $controller->resource_not_found(
        {
            callback => $callback,
            resource_name => $arguments->{publisherName}
        }
    ) unless defined $publisher;

    my (@ok, @ko);

    if (defined (my $publisher_runtime = $controller->daemon()->{core}->{runtime_per_publisher}->{$publisher->{name}})) {
        if ($publisher->{connectable}) {
            $controller->render_later();

            my $publisher_runtime = $controller->daemon()->{core}->{runtime_per_publisher}->{$publisher->{name}};

            collect(
                $publisher_runtime->rpc(
                    action => 'is_connecting'
                ),
                $publisher_runtime->rpc(
                    action => 'is_connected'
                ),
                $publisher_runtime->rpc(
                    action => 'is_disconnecting'
                ),
                $publisher_runtime->rpc(
                    action => 'is_disconnected'
                )
            )->then(
                sub {
                    my %status;

                    ($status{connecting}, $status{connected}, $status{disconnecting}, $status{disconnected}) = @_;

                    $status{$_} = $status{$_}->[0] ? 1 : 0 for keys %status;

                    $status{name} = $publisher->{name};

                    $controller->$callback(
                        \%status,
                        200
                    );
                }
            )->catch(
                sub {
                    push @ko, $publisher->full_name() . ': ' . shift;

                    $controller->$callback(
                        $controller->ok_ko(\@ok, \@ko),
                        500
                    );
                }
            );

            return;
        } else {
            push @ko, $publisher->full_name() . ': this publisher is not connectable.',
        }
    } else {
        push @ko, $publisher->full_name() . ': the runtime is not yet initialized.'
    }

    $controller->$callback(
        $controller->ok_ko(\@ok, \@ko),
        400
    );
}

sub show_publisher_amount_of_events {
    my ($controller, $arguments, $callback) = @_;

    my $publisher = $controller->daemon()->{core}->{publishers}->definition_by_name($arguments->{publisherName});

    return $controller->resource_not_found(
        {
            callback => $callback,
            resource_name => $arguments->{publisherName}
        }
    ) unless defined $publisher;

    if (defined (my $publisher_runtime = $controller->daemon()->{core}->{runtime_per_publisher}->{$publisher->{name}})) {
        $controller->$callback(
            {
                amount_of_events_in_queue => scalar @{$publisher_runtime->{queue}}
            },
            200
        );
    } else {
        $controller->$callback(
            $controller->ok_ko(
                [
                    $publisher->full_name() . ': the runtime is not yet initialized.'
                ],
                []
            ),
            400
        );
    }
}

sub push_event_to_a_publisher {
    my ($controller, $arguments, $callback) = @_;

    my $publisher = $controller->daemon()->{core}->{publishers}->definition_by_name($arguments->{publisherName});

    return $controller->resource_not_found(
        {
            callback => $callback,
            resource_name => $arguments->{publisherName}
        }
    ) unless defined $publisher;

    my $publisher_runtime = $controller->daemon()->{core}->{runtime_per_publisher}->{$publisher->{name}};

    my (@ok, @ko);

    if (defined $publisher_runtime) {
        local $@;

        eval {
            $publisher_runtime->push_in_queue(
                {
                    %{$arguments->{publisherEvent}},
                    %{
                        {
                            status => 'std'
                        }
                    }
                }
            );
        };

        unless ($@) {
            push @ok, $publisher->full_name() . ': pushing an event to the queue.';
        } else {
            push @ko, $publisher->full_name() . ': an error occurred while manually pushing an event to the queue: ' . $@ . '.';
        }
    } else {
        push @ko, $publisher->full_name() . ': the runtime is not yet initialized.';
    }

    $controller->$callback(
        $controller->ok_ko(\@ok, \@ko),
        @ko ? 400 : 201
    );
}

sub delete_all_events_from_a_publisher {
    my ($controller, $arguments, $callback) = @_;

    my $publisher = $controller->daemon()->{core}->{publishers}->definition_by_name($arguments->{publisherName});

    return $controller->resource_not_found(
        {
            callback => $callback,
            resource_name => $arguments->{publisherName}
        }
    ) unless defined $publisher;

    my $publisher_runtime = $controller->daemon()->{core}->{runtime_per_publisher}->{$publisher->{name}};

    my (@ok, @ko);

    if (defined $publisher_runtime) {
        $publisher_runtime->clear_queue();

        push @ok, $publisher->full_name() . ': queue cleared.';
    } else {
        push @ko, $publisher->full_name() . ': the runtime is not yet initialized.';
    }

    $controller->$callback(
        $controller->ok_ko(\@ok, \@ko),
        @ko ? 400 : 200
    );
}

sub connect_publisher {
    my ($controller, $arguments, $callback) = @_;

    my $publisher = $controller->daemon()->{core}->{publishers}->definition_by_name($arguments->{publisherName});

    return $controller->resource_not_found(
        {
            callback => $callback,
            resource_name => $arguments->{publisherName}
        }
    ) unless defined $publisher;

    my (@ok, @ko);

    local $@;

    eval {
        $controller->daemon()->{core}->connect_publisher_by_name($publisher->{name});
    };

    unless ($@) {
        push @ok, $publisher->full_name() . ': connecting.';
    } else {
        push @ko, $publisher->full_name() . ': the runtime is not yet initialized: ' . $@ . '.';
    }

    $controller->$callback(
        $controller->ok_ko(\@ok, \@ko),
        @ko ? 400 : 200
    );
}

sub disconnect_publisher {
    my ($controller, $arguments, $callback) = @_;

    my $publisher = $controller->daemon()->{core}->{publishers}->definition_by_name($arguments->{publisherName});

    return $controller->resource_not_found(
        {
            callback => $callback,
            resource_name => $arguments->{publisherName}
        }
    ) unless defined $publisher;

    my (@ok, @ko);

    local $@;

    eval {
        $controller->daemon()->{core}->disconnect_publisher_by_name($publisher->{name});
    };

    unless ($@) {
        push @ok, $publisher->full_name() . ': disconnecting.';
    } else {
        push @ko, $publisher->full_name() . ': the runtime is not yet initialized: ' . $@ . '.';
    }

    $controller->$callback(
        $controller->ok_ko(\@ok, \@ko),
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

Navel::Scheduler::Mojolicious::Application::Controller::Swagger2::Publisher

=head1 COPYRIGHT

Copyright (C) 2015 Yoann Le Garff, Nicolas Boquet and Yann Le Bras

=head1 LICENSE

navel-scheduler is licensed under the Apache License, Version 2.0

=cut
