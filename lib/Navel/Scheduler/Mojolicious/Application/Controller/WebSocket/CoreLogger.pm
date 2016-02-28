# Copyright 2015 Navel-IT
# navel-scheduler is developed by Yoann Le Garff, Nicolas Boquet and Yann Le Bras under GNU GPL v3

#-> BEGIN

#-> initialization

package Navel::Scheduler::Mojolicious::Application::Controller::WebSocket::CoreLogger 0.1;

use Mojo::Base 'Mojolicious::Controller';

#-> methods

sub stream {
    my $controller = shift;

    my $tx = $controller->tx();

    my $tx_id = sprintf '%s', $tx;

    $controller->scheduler()->{core}->{logger_callbacks}->{$tx_id} = sub {
        my $logger = shift;

        $tx->send(
            {
                json => $_
            }
        ) for @{$logger->{queue}};
    };

    $controller->on(
        finish => sub {
            delete $controller->scheduler()->{logger_callbacks}->{$tx_id};
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

Navel::Scheduler::Mojolicious::Application::Controller::WebSocket::CoreLogger

=head1 AUTHOR

Yoann Le Garff, Nicolas Boquet and Yann Le Bras

=head1 LICENSE

GNU GPL v3

=cut
