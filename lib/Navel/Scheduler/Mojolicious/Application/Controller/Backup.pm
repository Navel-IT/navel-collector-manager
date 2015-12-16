# Copyright 2015 Navel-IT
# navel-scheduler is developed by Yoann Le Garff, Nicolas Boquet and Yann Le Bras under GNU GPL v3

#-> BEGIN

#-> initialization

package Navel::Scheduler::Mojolicious::Application::Controller::Backup;

use Mojo::Base 'Mojolicious::Controller';

#-> methods

sub save_all_configuration {
    my ($controller, $arguments, $callback) = @_;

    my (@ok, @ko);

    my $save_configuration_on_success = sub {
        $controller->scheduler()->{core}->{logger}->push_in_queue(
            message => shift() . ': runtime configuration successfully saved.',
            severity => 'notice'
        );
    };

    my $save_configuration_on_error = sub {
        $controller->scheduler()->{core}->{logger}->push_in_queue(
            message => 'an error occurred while saving the runtime configuration: ' . shift() . '.',
            severity => 'error'
        );
    };

    $controller->scheduler()->{core}->{collectors}->write(
        file_path => $controller->scheduler()->{configuration}->{definition}->{collectors}->{definitions_from_file},
        async => 1,
        on_success => $save_configuration_on_success,
        on_error => $save_configuration_on_error
    );

    $controller->scheduler()->{core}->{rabbitmq}->write(
        file_path => $controller->scheduler()->{configuration}->{definition}->{rabbitmq}->{definitions_from_file},
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

=head1 NAME

Navel::Scheduler::Mojolicious::Application::Controller::Backup

=head1 AUTHOR

Yoann Le Garff, Nicolas Boquet and Yann Le Bras

=head1 LICENSE

GNU GPL v3

=cut
