# Copyright 2015 Navel-IT
# navel-scheduler is developed by Yoann Le Garff, Nicolas Boquet and Yann Le Bras under GNU GPL v3

#-> BEGIN

#-> initialization

package Navel::Scheduler::Mojolicious::Application::Controller::Product 0.1;

use Mojo::Base 'Mojolicious::Controller';

#-> methods

sub show_status {
    my ($controller, $arguments, $callback) = @_;

    $controller->$callback(
        {
            version => $controller->scheduler()->VERSION(),
            api_version => $controller->app()->defaults()->{swagger_spec}->get('/info/version')
        },
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

Navel::Scheduler::Mojolicious::Application::Controller::Product

=head1 AUTHOR

Yoann Le Garff, Nicolas Boquet and Yann Le Bras

=head1 LICENSE

GNU GPL v3

=cut

