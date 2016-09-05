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

use AnyEvent;

use File::ShareDir 'dist_dir';

use Navel::Scheduler::Parser;
use Navel::API::Swagger2::Scheduler;
use Navel::Logger::Message;
use Navel::Utils 'isint';

#-> methods

sub run {
    shift->SUPER::run(
        program_name => 'navel-scheduler'
    );
}

sub new {
    my $class = shift;

    state $self = $class->SUPER::new(
        @_,
        meta => Navel::Scheduler::Parser->new(),
        core_class => 'Navel::Scheduler::Core',
        mojolicious_application_class => 'Navel::Scheduler::Mojolicious::Application',
        swagger => Navel::API::Swagger2::Scheduler->new()
    );

    sub sigtrap_handler {
        $self->stop(
            delay => 5
        );
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

    $self->SUPER::start(@_)->{core}->register_core_logger()->init_collectors()->register_collectors()->init_publishers()->register_publishers()->recv();

    $self;
}

sub stop {
    my ($self, %options) = @_;

    state $stopping;

    unless ($stopping) {
        $stopping = 1;

        $options{delay} = 0 unless isint($options{delay}) > 0;

        local $@;

        $self->{core}->{logger}->notice('stopping the scheduler.');

        eval {
            $self->webserver(0) if $self->webserver();

            $self->{core}->delete_collectors()->delete_publishers();

            my $wait; $wait = AnyEvent->timer(
                after => $options{delay},
                cb => sub {
                    undef $wait;

                    $self->{core}->send();

                    $options{delay_callback}->() if ref $options{delay_callback} eq 'CODE';

                    $stopping = 0;
                }
            );
        };
    }

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
