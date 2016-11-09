# Copyright (C) 2015-2016 Yoann Le Garff, Nicolas Boquet and Yann Le Bras
# navel-scheduler is licensed under the Apache License, Version 2.0

#-> BEGIN

#-> initialization

package Navel::Scheduler 0.1;

use Navel::Base;

use parent 'Navel::Base::Daemon';

use AnyEvent;

use File::ShareDir 'dist_dir';

use Navel::Scheduler::Parser;
use Navel::API::Swagger2::Scheduler;

#-> class variables

my @signal_watchers;

#-> methods

sub run {
    shift->SUPER::run(
        program_name => 'navel-scheduler',
        before_starting => sub {
            my $self = shift;

            push @signal_watchers, AnyEvent->signal(
                signal => $_,
                cb => sub {
                    $self->stop(
                        sub {
                            exit;
                        }
                    );
                }
            ) for qw/
                INT
                QUIT
                TERM
            /;
        }
    );
}

sub new {
    my $class = shift;

    state $self = $class->SUPER::new(
        @_,
        meta => Navel::Scheduler::Parser->new,
        core_class => 'Navel::Scheduler::Core',
        mojolicious_application_class => 'Navel::Scheduler::Mojolicious::Application',
        swagger => Navel::API::Swagger2::Scheduler->new
    );

    if ($self->webserver) {
        $self->{webserver}->app->mode('production');

        my $mojolicious_app_home = dist_dir('Navel-Scheduler') . '/mojolicious/home';

        @{$self->{webserver}->app->renderer->paths} = ($mojolicious_app_home . '/templates');
        @{$self->{webserver}->app->static->paths} = ($mojolicious_app_home . '/public');
    }

    $self;
}

sub start {
    my $self = shift;

    $self->SUPER::start(@_)->{core}->register_core_logger->init_collectors->register_collectors->recv;

    $self;
}

sub stop {
    my ($self, $callback) = @_;

    state $stopping;

    unless ($stopping) {
        $stopping = 1;

        local $@;

        $self->{core}->{logger}->notice('stopping the scheduler.');

        eval {
            $self->webserver(0) if $self->webserver;

            $self->{core}->delete_collectors;

            my $wait; $wait = AnyEvent->timer(
                after => 5,
                cb => sub {
                    undef $wait;

                    $self->{core}->send;

                    $callback->() if ref $callback eq 'CODE';

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

Copyright (C) 2015-2016 Yoann Le Garff, Nicolas Boquet and Yann Le Bras

=head1 LICENSE

navel-scheduler is licensed under the Apache License, Version 2.0

=cut
