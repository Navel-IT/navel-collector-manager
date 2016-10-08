# Copyright (C) 2015-2016 Yoann Le Garff, Nicolas Boquet and Yann Le Bras
# navel-scheduler is licensed under the Apache License, Version 2.0

#-> BEGIN

#-> initialization

package Navel::Scheduler::Mojolicious::Application::Controller::Swagger2::Collector 0.1;

use Navel::Base;

use Promises 'collect';

use Mojo::Base 'Mojolicious::Controller';

#-> methods

sub list_collectors {
    my ($controller, $arguments, $callback) = @_;

    $controller->$callback(
        $controller->daemon()->{core}->{collectors}->all_by_property_name('name'),
        200
    );
}

sub new_collector {
    my ($controller, $arguments, $callback) = @_;

    return $controller->resource_already_exists(
        {
            callback => $callback,
            resource_name => $arguments->{collector}->{name}
        }
    ) if defined $controller->daemon()->{core}->{collectors}->definition_by_name($arguments->{collector}->{name});

    my (@ok, @ko);

    local $@;

    my $collector = eval {
        $controller->daemon()->{core}->{collectors}->add_definition($arguments->{collector});
    };

    unless ($@) {
        $controller->daemon()->{core}->init_collector_by_name($collector->{name})->register_collector_by_name($collector->{name});

        push @ok, $collector->full_name() . ': added.';
    } else {
        push @ko, $@;
    }

    $controller->$callback(
        $controller->ok_ko(\@ok, \@ko),
        @ko ? 400 : 201
    );
}

sub show_collector {
    my ($controller, $arguments, $callback) = @_;

    my $collector = $controller->daemon()->{core}->{collectors}->definition_properties_by_name($arguments->{collectorName});

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

sub update_collector {
    my ($controller, $arguments, $callback) = @_;

    my $collector = $controller->daemon()->{core}->{collectors}->definition_by_name($arguments->{collectorName});

    return $controller->resource_not_found(
        {
            callback => $callback,
            resource_name => $arguments->{collectorName}
        }
    ) unless defined $collector;

    my (@ok, @ko);

    local $@;

    delete $arguments->{collector}->{name};

    $arguments->{collector} = {
        %{$collector->properties()},
        %{$arguments->{collector}}
    };

    eval {
        $controller->daemon()->{core}->delete_collector_and_definition_associated_by_name($arguments->{collector}->{name});
    };

    unless ($@) {
        my $collector = eval {
            $controller->daemon()->{core}->{collectors}->add_definition($arguments->{collector});
        };

        unless ($@) {
            $controller->daemon()->{core}->init_collector_by_name($collector->{name})->register_collector_by_name($collector->{name});

            push @ok, $collector->full_name() . ': modified.';
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

sub delete_collector {
    my ($controller, $arguments, $callback) = @_;

    my $collector = $controller->daemon()->{core}->{collectors}->definition_by_name($arguments->{collectorName});

    return $controller->resource_not_found(
        {
            callback => $callback,
            resource_name => $arguments->{collectorName}
        }
    ) unless defined $collector;

    my (@ok, @ko);

    local $@;

    eval {
        $controller->daemon()->{core}->delete_collector_and_definition_associated_by_name($collector->{name});
    };

    unless ($@) {
        push @ok, $collector->full_name() . ': killed, unregistered and deleted.';
    } else {
        push @ko, $@;
    }

    $controller->$callback(
        $controller->ok_ko(\@ok, \@ko),
        @ko ? 400 : 200
    );
}

sub show_associated_queue {
    my ($controller, $arguments, $callback) = @_;

    my $collector = $controller->daemon()->{core}->{collectors}->definition_by_name($arguments->{collectorName});

    return $controller->resource_not_found(
        {
            callback => $callback,
            resource_name => $arguments->{collectorName}
        }
    ) unless defined $collector;

    $controller->render_later();

    $controller->daemon()->{core}->{worker_per_collector}->{$collector->{name}}->rpc(undef, 'queue')->then(
        sub {
            $controller->$callback(
                {
                    amount_of_events => shift
                },
                200
            );
        }
    )->catch(
        sub {
            $controller->$callback(
                $controller->ok_ko(
                    [],
                    [
                        $collector->full_name() . ': unexpected error.'
                    ]
                ),
                500
            );
        }
    );
}

sub delete_all_events_from_the_associated_queue {
    my ($controller, $arguments, $callback) = @_;

    my $collector = $controller->daemon()->{core}->{collectors}->definition_by_name($arguments->{collectorName});

    return $controller->resource_not_found(
        {
            callback => $callback,
            resource_name => $arguments->{collectorName}
        }
    ) unless defined $collector;

    $controller->render_later();

    my (@ok, @ko);

    $controller->daemon()->{core}->{worker_per_collector}->{$collector->{name}}->rpc(undef, 'dequeue')->then(
        sub {
            push @ok, $collector->full_name() . ': queue cleared.';
        }
    )->catch(
        sub {
            push @ko, $collector->full_name() . ': ' . (@_ ? join ', ', @_ : 'unexpected error') . '.';
        }
    )->finally(
        sub {
            $controller->$callback(
                $controller->ok_ko(\@ok, \@ko),
                @ko ? 500 : 200
            );
        }
    );
}

sub show_associated_publisher_connection_status {
    my ($controller, $arguments, $callback) = @_;

    my $collector = $controller->daemon()->{core}->{collectors}->definition_by_name($arguments->{collectorName});

    return $controller->resource_not_found(
        {
            callback => $callback,
            resource_name => $arguments->{collectorName}
        }
    ) unless defined $collector;

    my $collector_worker = $controller->daemon()->{core}->{worker_per_collector}->{$collector->{name}};

    $controller->render_later();

    my $connectable;

    $collector_worker->rpc($collector->{publisher}->{backend}, 'is_connectable')->then(
        sub {
            collect(
                $collector_worker->rpc($collector->{publisher}->{backend}, 'is_connecting'),
                $collector_worker->rpc($collector->{publisher}->{backend}, 'is_connected'),
                $collector_worker->rpc($collector->{publisher}->{backend}, 'is_disconnecting'),
                $collector_worker->rpc($collector->{publisher}->{backend}, 'is_disconnected')
            ) if $connectable = shift;
        }
    )->then(
        sub {
            my %status;

            ($status{connecting}, $status{connected}, $status{disconnecting}, $status{disconnected}) = @_;

            $status{$_} = $status{$_}->[0] ? 1 : 0 for keys %status;

            $status{connectable} = $connectable ? 1 : 0;

            $controller->$callback(
                \%status,
                200
            );
        }
    )->catch(
        sub {
            $controller->$callback(
                $controller->ok_ko(
                    [],
                    [
                        $collector->full_name() . ': ' . (@_ ? join ', ', @_ : 'unexpected error') . '.'
                    ]
                ),
                500
            );
        }
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

Navel::Scheduler::Mojolicious::Application::Controller::Swagger2::Collector

=head1 COPYRIGHT

Copyright (C) 2015-2016 Yoann Le Garff, Nicolas Boquet and Yann Le Bras

=head1 LICENSE

navel-scheduler is licensed under the Apache License, Version 2.0

=cut
