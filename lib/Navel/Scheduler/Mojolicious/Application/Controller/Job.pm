# Copyright 2015 Navel-IT
# navel-scheduler is developed by Yoann Le Garff, Nicolas Boquet and Yann Le Bras under GNU GPL v3

#-> BEGIN

#-> initialization

package Navel::Scheduler::Mojolicious::Application::Controller::Job 0.1;

use Mojo::Base 'Mojolicious::Controller';

#-> methods

sub list_job_types {
    my ($controller, $arguments, $callback) = @_;

    $controller->$callback(
        [
            keys %{$controller->scheduler()->{core}->{job_types}}
        ],
        200
    );
}

sub list_job_by_type {
    my ($controller, $arguments, $callback) = @_;

    $controller->$callback(
        $controller->scheduler()->{core}->job_type_exists($arguments->{jobType}) ? [
            map {
                $_->{name}
            } @{$controller->scheduler()->{core}->jobs_by_type($arguments->{jobType})}
        ] : [],
        200
    );
}

sub show_job_by_type_and_name {
    my ($controller, $arguments, $callback) = @_;

    my %job_properties;

    if ($controller->scheduler()->{core}->job_type_exists($arguments->{jobType})) {
        my $job = $controller->scheduler()->{core}->job_by_type_and_name($arguments->{jobType}, $arguments->{jobName});

        if (defined $job) {
            $job_properties{name} = $arguments->{jobName};
            $job_properties{type} = $arguments->{jobType};

            $job_properties{$_} = $job->{$_} for qw/
                enabled
                singleton
                running
            /;
        }
    }

    $controller->$callback(
        \%job_properties,
        200
    );
}

sub action_on_job_by_type_and_name {
    my ($controller, $arguments, $callback) = @_;

    my (@ok, @ko);

    if ($controller->scheduler()->{core}->job_type_exists($arguments->{jobType})) {
        my $job = $controller->scheduler()->{core}->job_by_type_and_name($arguments->{jobType}, $arguments->{jobName});

        if (defined $job) {
            my $enable_property = 'enabled';

            if ($arguments->{jobAction} eq 'enable') {
                $job->{$enable_property} = 1;

                push @ok, 'enabling job ' . $job->{name} . '.';
            } elsif ($arguments->{jobAction} eq 'disable') {
                $job->{$enable_property} = 0;

                push @ok, 'disabling job ' . $job->{name} . '.';
            } elsif ($arguments->{jobAction} eq 'execute') {
                $job->exec();

                push @ok, 'executing job ' . $job->{name} . '.';
            }
        } else {
            push @ko, 'job ' . $arguments->{jobName} . " don't exists.";
        }
    } else {
        push @ko, 'job ' . $arguments->{jobType} . " don't exists";
    }

    $controller->$callback(
        $controller->ok_ko(
            {
                ok => \@ok,
                ko => \@ko
            }
        ),
        200
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

Navel::Scheduler::Mojolicious::Application::Controller::Job

=head1 AUTHOR

Yoann Le Garff, Nicolas Boquet and Yann Le Bras

=head1 LICENSE

GNU GPL v3

=cut
