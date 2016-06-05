# Copyright (C) 2015 Yoann Le Garff, Nicolas Boquet and Yann Le Bras
# navel-scheduler is licensed under the Apache License, Version 2.0

#-> BEGIN

#-> initialization

package Navel::Scheduler::Mojolicious::Application::Controller::Swagger2::Backup 0.1;

use Navel::Base;

use Mojo::Base 'Mojolicious::Controller';

#-> methods

sub save_all_configuration {
    my ($controller, $arguments, $callback) = @_;

    $controller->render_later();

    my (@ok, @ko);

    my $done_counter = my $done_limit = 0;

    for (
        $controller->daemon()->{core}->{collectors},
        $controller->daemon()->{core}->{publishers},
        $controller->daemon()->{webservices},
        $controller->daemon()->{configuration}
    ) {
        $_->write(
            async => 1,
            on_success => sub {
                push @ok, shift . ': runtime configuration successfully saved.';

                $done_counter++;
            },
            on_error => sub {
                push @ko, shift;

                $done_counter++;
            }
        );

        $done_limit++;
    }

    my $id; $id = Mojo::IOLoop->recurring(
        0.5 => sub {
            if ($done_counter >= $done_limit) {
                shift->remove($id);

                $controller->$callback(
                    $controller->ok_ko(\@ok, \@ko),
                    200
                );
            }
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

Navel::Scheduler::Mojolicious::Application::Controller::Swagger2::Backup

=head1 COPYRIGHT

Copyright (C) 2015 Yoann Le Garff, Nicolas Boquet and Yann Le Bras

=head1 LICENSE

navel-scheduler is licensed under the Apache License, Version 2.0

=cut
