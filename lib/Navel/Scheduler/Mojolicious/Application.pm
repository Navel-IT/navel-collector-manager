# Copyright (C) 2015 Yoann Le Garff, Nicolas Boquet and Yann Le Bras
# navel-scheduler is licensed under the Apache License, Version 2.0

#-> BEGIN

#-> initialization

package Navel::Scheduler::Mojolicious::Application 0.1;

use Mojo::Base 'Mojolicious';

use Mojo::Util 'secure_compare';

use Navel::Logger::Message;
use Navel::API::Swagger2::Scheduler;
use Navel::Utils qw/
    croak
    blessed
/;

#-> methods

sub new {
    my ($class, $scheduler) = @_;

    croak('scheduler must be of Navel::Scheduler class') unless blessed($scheduler) && $scheduler->isa('Navel::Scheduler');

    my $self = $class->SUPER::new();

    $self->helper(
        scheduler => sub {
            $scheduler;
        }
    );
    
    $self->plugin('Navel::Mojolicious::Plugin::JSON::XS');

    $self->plugin('Navel::Mojolicious::Plugin::Logger',
        {
            logger => $self->scheduler()->{core}->{logger}
        }
    );
    
    $self->plugin('Navel::Mojolicious::Plugin::Swagger2::StdResponses');

    $self->log()->level('debug')->unsubscribe('message')->on(
        message => sub {
            my ($log, $level, @lines) = @_;

            my $method = $level eq 'debug' ? $level : 'info';

            $self->scheduler()->{core}->{logger}->$method(
                Navel::Logger::Message->stepped_message('Mojolicious:', \@lines)
            );
        }
    );

    $self;
}

sub startup {
    my $self = shift;

    local $@;

    $self->secrets(rand);

    my $routes = $self->routes();

    my $authenticated = $routes->under(
        '/',
        sub {
            my $controller = shift;

            my $userinfo = $controller->req()->url()->to_abs()->userinfo();

            unless (secure_compare(defined $userinfo ? $userinfo : '', $self->scheduler()->{configuration}->{definition}->{webservices}->{credentials}->{login} . ':' . $self->scheduler()->{configuration}->{definition}->{webservices}->{credentials}->{password})) {
                $controller->res()->headers()->www_authenticate('Basic');

                $controller->render(
                    json => $controller->ok_ko(
                        [],
                        [
                            'unauthorized: access is denied due to invalid credentials.'
                        ]
                    ),
                    status => 401
                );

                return undef;
            }
        }
    );

    my $swagger_spec = Navel::API::Swagger2::Scheduler->new();

    $self->plugin(
        'Mojolicious::Plugin::Swagger2' => {
            swagger => $swagger_spec,
            route => $authenticated
        }
    );

    $authenticated->websocket('/api/logger/stream')->to('WebSocket::CoreLogger#stream');

    $self->hook(
        before_render => sub {
            my ($controller, $arguments) = @_;

            my (@ok, @ko);

            my $template = defined $arguments->{template} ? $arguments->{template} : '';

            if ($template eq 'exception') {
                my $exception_message = $controller->stash('exception')->message();

                push @ko, $exception_message;

                $controller->scheduler()->{core}->{logger}->err(
                    Navel::Logger::Message->stepped_message(\@ko)
                );
            } elsif ($template eq 'not_found') {
                push @ko, "the page you were looking for doesn't exist."
            } else {
                return;
            }

            $arguments->{json} = {
                ok => \@ok,
                ko => \@ko
            };
        }
    );

    $self->defaults(
        swagger_spec => $swagger_spec->api_spec()
    );

    $self->log()->debug($@) if $@;

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

Navel::Scheduler::Mojolicious::Application

=head1 COPYRIGHT

Copyright (C) 2015 Yoann Le Garff, Nicolas Boquet and Yann Le Bras

=head1 LICENSE

navel-scheduler is licensed under the Apache License, Version 2.0

=cut
