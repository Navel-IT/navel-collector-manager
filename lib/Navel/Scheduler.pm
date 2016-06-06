# Copyright (C) 2015 Yoann Le Garff, Nicolas Boquet and Yann Le Bras
# navel-scheduler is licensed under the Apache License, Version 2.0

#-> BEGIN

#-> initialization

package Navel::Scheduler 0.1;

use Navel::Base;

use parent 'Navel::Base::Daemon';

use sigtrap (
    'handler' => \&sigtrap_handler,
    'normal-signals'
);

use File::ShareDir 'dist_dir';

use Navel::Scheduler::Parser;
use Navel::API::Swagger2::Scheduler;
use Navel::Logger::Message;

#-> methods

sub run {
    shift->SUPER::run('navel-scheduler');
}

sub new {
    my ($class, %options) = @_;

    state $self = $class->SUPER::new(
        %options,
        meta => Navel::Scheduler::Parser->new(),
        core_class => 'Navel::Scheduler::Core',
        mojolicious_application_class => 'Navel::Scheduler::Mojolicious::Application',
        swagger => Navel::API::Swagger2::Scheduler->new()
    );

    sub sigtrap_handler {
        $self->{core}->{logger}->notice(
            Navel::Logger::Message->stepped_message('catch a signal.',
                [
                    $!
                ]
            )
        )->notice('stopping the scheduler.')->flush_queue();

        $self->stop();
    }

    if ($self->webserver()) {
        $self->{webserver}->app()->mode('production');

        my $mojolicious_app_home = dist_dir('Navel-Scheduler') . '/mojolicious/home';

        @{$self->{webserver}->app()->renderer()->paths()} = ($mojolicious_app_home . '/templates');
        @{$self->{webserver}->app()->static()->paths()} = ($mojolicious_app_home . '/public');
    }

    $self;
}

sub start {
    my $self = shift;

    $self->SUPER::start(@_)->{core}->register_core_logger()->register_collectors()->init_publishers()->register_publishers()->recv();

    $self;
}

sub stop {
    my $self = shift;

    local $@;

    eval {
        $self->webserver(0) if $self->webserver();

        $self->{core}->delete_collectors()->delete_publishers()->send();
    };

    $self;
}

# sub AUTOLOAD {}

# sub DESTROY {}

1;

#-> END

__END__

=pod

=encoding utf8

=head1 NAME

Navel::Scheduler

=head1 COPYRIGHT

Copyright (C) 2015 Yoann Le Garff, Nicolas Boquet and Yann Le Bras

=head1 LICENSE

navel-scheduler is licensed under the Apache License, Version 2.0

=cut
