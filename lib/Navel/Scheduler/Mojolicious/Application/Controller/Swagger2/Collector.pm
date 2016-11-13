# Copyright (C) 2015-2016 Yoann Le Garff, Nicolas Boquet and Yann Le Bras
# navel-scheduler is licensed under the Apache License, Version 2.0

#-> BEGIN

#-> initialization

package Navel::Scheduler::Mojolicious::Application::Controller::Swagger2::Collector 0.1;

use Navel::Base;

use Mojo::Base 'Mojolicious::Controller';

use parent 'Navel::Base::WorkerManager::Mojolicious::Application::Controller::Swagger2::Worker';

use Promises 'collect';

#-> methods

sub show_associated_publisher_connection_status {
    my ($controller, $arguments, $callback) = @_;

    my $definition = $controller->daemon->{core}->{definitions}->definition_by_name($arguments->{name});

    return $controller->resource_not_found(
        {
            callback => $callback,
            resource_name => $arguments->{name}
        }
    ) unless defined $definition;

    my $worker_worker = $controller->daemon->{core}->{worker_per_definition}->{$definition->{name}};

    $controller->render_later;

    my $connectable;

    $worker_worker->rpc($definition->{publisher_backend}, 'is_connectable')->then(
        sub {
            collect(
                $worker_worker->rpc($definition->{publisher_backend}, 'is_connecting'),
                $worker_worker->rpc($definition->{publisher_backend}, 'is_connected'),
                $worker_worker->rpc($definition->{publisher_backend}, 'is_disconnecting'),
                $worker_worker->rpc($definition->{publisher_backend}, 'is_disconnected')
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
                        $definition->full_name . ': ' . (@_ ? join ', ', @_ : 'unexpected error') . '.'
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
