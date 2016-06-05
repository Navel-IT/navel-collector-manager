# Copyright (C) 2015 Yoann Le Garff, Nicolas Boquet and Yann Le Bras
# navel-scheduler is licensed under the Apache License, Version 2.0

#-> BEGIN

#-> initialization

package Navel::Scheduler::Mojolicious::Application::Controller::Swagger2::WebService 0.1;

use Navel::Base;

use Mojo::Base 'Mojolicious::Controller';

#-> methods

sub list_webservices {
    my ($controller, $arguments, $callback) = @_;

    $controller->$callback(
        $controller->daemon()->{webservices}->name(),
        200
    );
}

sub show_webservice {
    my ($controller, $arguments, $callback) = @_;

    my $webservice = $controller->daemon()->{webservices}->definition_properties_by_name($arguments->{webServiceName});

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

Navel::Scheduler::Mojolicious::Application::Controller::Swagger2::WebService

=head1 COPYRIGHT

Copyright (C) 2015 Yoann Le Garff, Nicolas Boquet and Yann Le Bras

=head1 LICENSE

navel-scheduler is licensed under the Apache License, Version 2.0

=cut
