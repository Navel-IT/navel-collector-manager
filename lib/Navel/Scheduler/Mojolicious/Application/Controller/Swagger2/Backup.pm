# Copyright (C) 2015 Yoann Le Garff, Nicolas Boquet and Yann Le Bras
# navel-scheduler is licensed under the Apache License, Version 2.0

#-> BEGIN

#-> initialization

package Navel::Scheduler::Mojolicious::Application::Controller::Swagger2::Backup 0.1;

use Navel::Base;

use Mojo::Base 'Mojolicious::Controller';

use Navel::Logger::Message;

#-> methods

sub save_all_configuration {
    my ($controller, $arguments, $callback) = @_;

    my (@ok, @ko);

    my $save_configuration_on_success = sub {
        $controller->scheduler()->{core}->{logger}->notice(shift . ': runtime configuration successfully saved.');
    };

    my $save_configuration_on_error = sub {
        $controller->scheduler()->{core}->{logger}->err(
            Navel::Logger::Message->stepped_message('an error occurred while saving the runtime configuration.',
                [
                    shift
                ]
            )
        );
    };

    $controller->scheduler()->{core}->{$_}->write(
        file_path => $controller->scheduler()->{configuration}->{definition}->{$_}->{definitions_from_file},
        async => 1,
        on_success => $save_configuration_on_success,
        on_error => $save_configuration_on_error
    ) for qw/
        collectors
        publishers
    /;

    $controller->scheduler()->{webservices}->write(
        file_path => $controller->scheduler()->{configuration}->{definition}->{webservices}->{definitions_from_file},
        async => 1,
        on_success => $save_configuration_on_success,
        on_error => $save_configuration_on_error
    );

    $controller->scheduler()->{configuration}->write(
        file_path => $controller->scheduler()->{main_configuration_file_path},
        async => 1,
        on_success => $save_configuration_on_success,
        on_error => $save_configuration_on_error
    );

    push @ok, 'saving the runtime configuration.';

    $controller->$callback(
        $controller->ok_ko(\@ok, \@ko),
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

Navel::Scheduler::Mojolicious::Application::Controller::Swagger2::Backup

=head1 COPYRIGHT

Copyright (C) 2015 Yoann Le Garff, Nicolas Boquet and Yann Le Bras

=head1 LICENSE

navel-scheduler is licensed under the Apache License, Version 2.0

=cut
