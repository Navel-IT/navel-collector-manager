# Copyright (C) 2015-2017 Yoann Le Garff, Nicolas Boquet and Yann Le Bras
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
    shift->_show_associated_queue('queue');
}

sub delete_all_events_from_associated_queue {
    shift->_delete_all_events_from_associated_queue('dequeue');
}

sub show_associated_publisher_connection_status {
    shift->_show_associated_pubsub_connection_status('publisher_backend');
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

Copyright (C) 2015-2017 Yoann Le Garff, Nicolas Boquet and Yann Le Bras

=head1 LICENSE

navel-scheduler is licensed under the Apache License, Version 2.0

=cut
