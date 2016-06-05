# Copyright (C) 2015 Yoann Le Garff, Nicolas Boquet and Yann Le Bras
# navel-scheduler is licensed under the Apache License, Version 2.0

#-> BEGIN

#-> initialization

package Navel::Scheduler::Mojolicious::Application::Controller::Swagger2::Publisher 0.1;

use Navel::Base;

use Mojo::Base 'Mojolicious::Controller';

use Mojo::JSON 'decode_json';

use Navel::Utils 'isint';

#-> methods

sub list_publishers {
    my ($controller, $arguments, $callback) = @_;

    $controller->$callback(
        $controller->daemon()->{core}->{publishers}->name(),
        200
    );
}

sub new_publisher {
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
            ) if defined $controller->daemon()->{core}->{publishers}->definition_by_name($body->{name});

            my $publisher = eval {
                $controller->daemon()->{core}->{publishers}->add_definition($body);
            };

            unless ($@) {
                $controller->daemon()->{core}->init_publisher_by_name($publisher->{name})->register_publisher_by_name($publisher->{name});

                push @ok, 'adding publisher ' . $publisher->{name} . '.';
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

    my (@ok, @ko);

    local $@;

    my $body = eval {
        decode_json($controller->req()->body());
    };

    unless ($@) {
        if (ref $body eq 'HASH') {
            my $publisher = $controller->daemon()->{core}->{publishers}->definition_by_name($arguments->{publisherName});

            return $controller->resource_not_found(
                {
                    callback => $callback,
                    resource_name => $arguments->{publisherName}
                }
            ) unless defined $publisher;

            delete $body->{name};

            $body = {
                %{$publisher->properties()},
                %{$body}
            };

            unless (my @validation_errors = @{$publisher->validate($body)}) {
                eval {
                    $controller->daemon()->{core}->delete_publisher_and_definition_associated_by_name($body->{name});
                };

                unless ($@) {
                    my $publisher = eval {
                        $controller->daemon()->{core}->{publishers}->add_definition($body);
                    };

                    unless ($@) {
                        $controller->daemon()->{core}->init_publisher_by_name($publisher->{name})->register_publisher_by_name($publisher->{name});

                        push @ok, 'modifying publisher ' . $publisher->{name} . '.';
                    } else {
                        push @ko, $@;
                    }
                } else {
                    push @ko, 'an unknown eror occurred while modifying the publisher.';
                }
            } else {
                push @ko, 'error(s) occurred while modifying publisher ' . $body->{name} . ':', \@validation_errors;
            }
        } else {
            push @ko, 'the request payload must represent a hash.';
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

    my (@ok, @ko);

    local $@;

    eval {
        $controller->daemon()->{core}->delete_publisher_and_definition_associated_by_name($publisher->{name});
    };

    unless ($@) {
        push @ok, 'killing, unregistering and deleting publisher ' . $arguments->{publisherName} . '.';
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

    my %status = (
        name => $publisher->{name}
    );

    my $publisher_runtime = $controller->daemon()->{core}->{runtime_per_publisher}->{$publisher->{name}};

    if ($status{connectable} = $publisher->{connectable}) {
        $controller->render_later();

        my @base_keys = keys %status;

        my @connectable_properties = qw/
            connecting
            connected
            disconnecting
            disconnected
        /;

        for my $connectable_property (@connectable_properties) {
            my $method = 'is_' . $connectable_property;

            if (defined $publisher_runtime) {
                $publisher_runtime->rpc(
                    method => $method,
                    callback => sub {
                        $status{$connectable_property} = shift ? 1 : 0;
                    }
                );
            } else {
                $status{$connectable_property} = 0;
            }
        }

        my $id; $id = Mojo::IOLoop->recurring(
            0.5 => sub {
                if (keys %status >= @base_keys + @connectable_properties) {
                    shift->remove($id);

                    $controller->$callback(
                        \%status,
                        200
                    );
                }
            }
        );
    } else {
        $controller->$callback(
            \%status,
            200
        );
    }
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
                    'the runtime of publisher ' . $publisher->{name} . ' is not yet initialized.'
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

    local $@;

    my $body = eval {
        decode_json($controller->req()->body());
    };

    unless ($@) {
        if (ref $body eq 'HASH') {
            if (defined $publisher_runtime) {
                eval {
                    $publisher_runtime->push_in_queue(
                        {
                            %{$body},
                            %{
                                {
                                    status => 'std'
                                }
                            }
                        }
                    );
                };

                unless ($@) {
                    push @ok, 'pushing an event to the queue of publisher ' . $publisher->{name} . '.';
                } else {
                    push @ko, 'an error occurred while manually pushing an event to the queue of publisher ' . $publisher->{name} . ': ' . $@ . '.';
                }
            } else {
                push @ko, 'the runtime of publisher ' . $publisher->{name} . ' is not yet initialized.';
            }
        } else {
            push @ko, 'the request payload must represent a hash.';
        }
    } else {
        push @ko, $@;
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

        push @ok, 'clearing queue for publisher ' . $publisher->{name} . '.';
    } else {
        push @ko, 'the runtime of publisher ' . $publisher->{name} . ' is not yet initialized.';
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
        push @ok, 'connecting publisher ' . $publisher->{name} . '.';
    } else {
        push @ko, 'connecting publisher ' . $publisher->{name} . ': the runtime of the publisher is not yet initialized: ' . $@ . '.';
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
        push @ok, 'disconnecting publisher ' . $publisher->{name} . '.';
    } else {
        push @ko, 'disconnecting publisher ' . $publisher->{name} . ': the runtime of the publisher is not yet initialized: ' . $@ . '.';
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
