# Copyright (C) 2015-2016 Yoann Le Garff, Nicolas Boquet and Yann Le Bras
# navel-scheduler is licensed under the Apache License, Version 2.0

#-> BEGIN

#-> initialization

package Navel::Scheduler::Mojolicious::Application::Controller::Swagger2::Collector 0.1;

use Navel::Base;

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

sub modify_collector {
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
        push @ok, $collector->full_name() . ': ' . ($collector->{async} ? 'killed, ' : '') . 'unregistered and deleted.';
    } else {
        push @ko, $@;
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

Navel::Scheduler::Mojolicious::Application::Controller::Swagger2::Collector

=head1 COPYRIGHT

Copyright (C) 2015-2016 Yoann Le Garff, Nicolas Boquet and Yann Le Bras

=head1 LICENSE

navel-scheduler is licensed under the Apache License, Version 2.0

=cut
