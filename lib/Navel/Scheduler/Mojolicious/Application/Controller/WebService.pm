# Copyright 2015 Navel-IT
# navel-scheduler is developed by Yoann Le Garff, Nicolas Boquet and Yann Le Bras under GNU GPL v3

#-> BEGIN

#-> initialization

package Navel::Scheduler::Mojolicious::Application::Controller::WebService 0.1;

use Mojo::Base 'Mojolicious::Controller';

#-> methods

sub list_webservices {
    my ($controller, $arguments, $callback) = @_;

    $controller->$callback(
        $controller->scheduler()->{webservices}->name(),
        200
    );
}

sub show_webservice {
    my ($controller, $arguments, $callback) = @_;

    my $webservice = $controller->scheduler()->{webservices}->definition_properties_by_name($arguments->{webServiceName});

    return $controller->resource_not_found(
        {
            callback => $callback,
            resource_name => $arguments->{webServiceName}
        }
    ) unless defined $webservice;

    $controller->$callback(
        $webservice,
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

Navel::Scheduler::Mojolicious::Application::Controller::WebService

=head1 AUTHOR

Yoann Le Garff, Nicolas Boquet and Yann Le Bras

=head1 LICENSE

GNU GPL v3

=cut

