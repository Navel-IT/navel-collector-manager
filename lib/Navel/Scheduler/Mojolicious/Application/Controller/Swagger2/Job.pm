# Copyright (C) 2015 Yoann Le Garff, Nicolas Boquet and Yann Le Bras
# navel-scheduler is licensed under the Apache License, Version 2.0

#-> BEGIN

#-> initialization

package Navel::Scheduler::Mojolicious::Application::Controller::Swagger2::Job 0.1;

use Navel::Base;

use Mojo::Base 'Mojolicious::Controller';

#-> methods

my $action_on_job_by_type_and_name = sub {
    my ($controller, $arguments, $callback, $jobAction) = @_;

    return $controller->resource_not_found(
        {
            callback => $callback
        }
    ) unless $controller->daemon()->{core}->job_type_exists($arguments->{jobType});

    my $job = $controller->daemon()->{core}->job_by_type_and_name($arguments->{jobType}, $arguments->{jobName});

    return $controller->resource_not_found(
        {
            callback => $callback,
            resource_name => $arguments->{jobName}
        }
    ) unless defined $job;

    my (@ok, @ko);

    my $enable_property = 'enabled';

    if ($jobAction eq 'enable') {
        $job->{$enable_property} = 1;

        push @ok, 'enabling job ' . $job->{name} . '.';
    } elsif ($jobAction eq 'disable') {
        $job->{$enable_property} = 0;

        push @ok, 'disabling job ' . $job->{name} . '.';
    } elsif ($jobAction eq 'execute') {
        $job->exec();

        push @ok, 'executing job ' . $job->{name} . '.';
    }

    $controller->$callback(
        $controller->ok_ko(\@ok, \@ko),
        200
    );
};

sub list_job_types {
    my ($controller, $arguments, $callback) = @_;

    $controller->$callback(
        [
            keys %{$controller->daemon()->{core}->{job_types}}
        ],
        200
    );
}

sub list_jobs_by_type {
    my ($controller, $arguments, $callback) = @_;

    return $controller->resource_not_found(
        {
            callback => $callback
        }
    ) unless $controller->daemon()->{core}->job_type_exists($arguments->{jobType});

    $controller->$callback(
        [
            map {
                $_->{name}
            } @{$controller->daemon()->{core}->jobs_by_type($arguments->{jobType})}
        ],
        200
    );
}

sub show_job_by_type_and_name {
    my ($controller, $arguments, $callback) = @_;

    return $controller->resource_not_found(
        {
            callback => $callback
        }
    ) unless $controller->daemon()->{core}->job_type_exists($arguments->{jobType});

    my $job = $controller->daemon()->{core}->job_by_type_and_name($arguments->{jobType}, $arguments->{jobName});

    return $controller->resource_not_found(
        {
            callback => $callback,
            resource_name => $arguments->{jobName}
        }
    ) unless defined $job;

    my %job_properties;

    $job_properties{name} = $arguments->{jobName};
    $job_properties{type} = $arguments->{jobType};

    $job_properties{$_} = $job->{$_} for qw/
        enabled
        singleton
        running
    /;

    $controller->$callback(
        \%job_properties,
        200
    );
}

sub enable_job_by_type_and_name {
    $action_on_job_by_type_and_name->(
        @_,
        'enable'
    );
}

sub execute_job_by_type_and_name {
    $action_on_job_by_type_and_name->(
        @_,
        'execute'
    );
}

sub disable_job_by_type_and_name {
    $action_on_job_by_type_and_name->(
        @_,
        'disable'
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

Navel::Scheduler::Mojolicious::Application::Controller::Swagger2::Job

=head1 COPYRIGHT

Copyright (C) 2015 Yoann Le Garff, Nicolas Boquet and Yann Le Bras

=head1 LICENSE

navel-scheduler is licensed under the Apache License, Version 2.0

=cut
