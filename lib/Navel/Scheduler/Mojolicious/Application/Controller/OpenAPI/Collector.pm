# Copyright (C) 2015-2016 Yoann Le Garff, Nicolas Boquet and Yann Le Bras
# navel-scheduler is licensed under the Apache License, Version 2.0

#-> BEGIN

#-> initialization

package Navel::Scheduler::Mojolicious::Application::Controller::OpenAPI::Collector 0.1;

use Navel::Base;

use Mojo::Base 'Mojolicious::Controller';

use parent 'Navel::Base::WorkerManager::Mojolicious::Application::Controller::OpenAPI::Worker';

use Promises 'collect';

#-> methods

sub show_associated_queue {
    my $controller = shift->openapi->valid_input || return;

    my $name = $controller->validation->param('name');

    my $definition = $controller->daemon->{core}->{definitions}->definition_by_name($name);

    return $controller->resource_not_found($name) unless defined $definition;

    $controller->render_later;

    $controller->daemon->{core}->{worker_per_definition}->{$definition->{name}}->rpc(undef, 'queue')->then(
        sub {
            $controller->render(
                openapi => {
                    amount_of_events => shift
                },
                status => 200
            );
        }
    )->catch(
        sub {
            $controller->render(
                openapi => $controller->ok_ko(
                    [],
                    [
                        $definition->full_name . ': ' . (@_ ? join ', ', @_ : 'unexpected error') . '.'
                    ]
                ),
                status => 500
            );
        }
    );
}

sub delete_all_events_from_associated_queue {
    my $controller = shift->openapi->valid_input || return;

    my $name = $controller->validation->param('name');

    my $definition = $controller->daemon->{core}->{definitions}->definition_by_name($name);

    return $controller->resource_not_found($name) unless defined $definition;

    $controller->render_later;

    my (@ok, @ko);

    $controller->daemon->{core}->{worker_per_definition}->{$definition->{name}}->rpc(undef, 'dequeue')->then(
        sub {
            push @ok, $definition->full_name . ': queue cleared.';
        }
    )->catch(
        sub {
            push @ko, $definition->full_name . ': ' . (@_ ? join ', ', @_ : 'unexpected error') . '.';
        }
    )->finally(
        sub {
            $controller->render(
                openapi => $controller->ok_ko(\@ok, \@ko),
                status => @ko ? 500 : 200
            );
        }
    );
}

sub show_associated_publisher_connection_status {
    my $controller = shift->openapi->valid_input || return;

    my $name = $controller->validation->param('name');

    my $definition = $controller->daemon->{core}->{definitions}->definition_by_name($name);

    return $controller->resource_not_found($name) unless defined $definition;

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

            $controller->render(
                openapi => \%status,
                status => 200
            );
        }
    )->catch(
        sub {
            $controller->render(
                openapi => $controller->ok_ko(
                    [],
                    [
                        $definition->full_name . ': ' . (@_ ? join ', ', @_ : 'unexpected error') . '.'
                    ]
                ),
                status => 500
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

Navel::Scheduler::Mojolicious::Application::Controller::OpenAPI::Collector

=head1 COPYRIGHT

Copyright (C) 2015-2016 Yoann Le Garff, Nicolas Boquet and Yann Le Bras

=head1 LICENSE

navel-scheduler is licensed under the Apache License, Version 2.0

=cut
