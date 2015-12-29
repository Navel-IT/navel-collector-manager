# Copyright 2015 Navel-IT
# navel-scheduler is developed by Yoann Le Garff, Nicolas Boquet and Yann Le Bras under GNU GPL v3

#-> BEGIN

#-> initialization

package Navel::Scheduler::Mojolicious::Application::Controller::Publisher 0.1;

use Mojo::Base 'Mojolicious::Controller';

use Navel::Utils 'decode_json';

#-> methods

sub list_publishers {
    my ($controller, $arguments, $callback) = @_;

    $controller->$callback(
        [
            map {
                $_->{definition}->{name}
            } @{$controller->scheduler()->{core}->{publishers}}
        ],
        200
    );
}

sub show_publisher {
    my ($controller, $arguments, $callback) = @_;

    my %status;

    if (defined (my $publisher = $controller->scheduler()->{core}->publisher_by_name($arguments->{publisherName}))) {
        $status{name} = $publisher->{definition}->{name};

        for (qw/
            connecting
            connected
            disconnecting
            disconnected
        /) {
            my $method = 'is_' . $_;

            $status{$_} = $publisher->$method() || 0;
        };
    }

    $controller->$callback(
        \%status,
        200
    );
}

sub list_events_of_a_publisher {
    my ($controller, $arguments, $callback) = @_;

    my $publisher = $controller->scheduler()->{core}->publisher_by_name($arguments->{publisherName});

    $controller->$callback(
        defined $publisher ? [
            map {
                $_->serialized_datas()
            } @{$publisher->{queue}}
        ] : [],
        200
    );
}

sub push_event_to_a_publisher {
    my ($controller, $arguments, $callback) = @_;

    my (@ok, @ko);

    if (defined (my $publisher = $controller->scheduler()->{core}->publisher_by_name($arguments->{publisherName}))) {
        local $@;

        my $body = eval {
            decode_json($controller->req()->body());
        };

        unless ($@) {
            if (ref $body eq 'HASH') {
                if (defined ($body->{status_method} = delete $body->{status})) {
                    if ($body->{status_method} eq 'ok' || $body->{status_method} eq 'ko_no_source' || $body->{status_method} eq 'ko_exception') {
                        $body->{status_method} = 'set_status_to_' . $body->{status_method};
                    } else {
                         push @ko, 'event status is incorrect.';
                    }
                }

                unless (@ko) {
                    eval {
                        $publisher->push_in_queue(%{$body});
                    };

                    unless ($@) {
                        push @ok, 'pushing an event to the queue of publisher ' . $publisher->{definition}->{name} . '.';
                    } else {
                        push @ko, 'an error occurred while manually pushing an event to the queue of publisher ' . $publisher->{definition}->{name} . ': ' . $@ . '.';
                    }
                }
            } else {
                push @ko, 'body need to represent a hashtable.';
            }
        } else {
            push @ko, $@;
        }
    } else {
        push @ko, 'publisher ' . $arguments->{publisherName} . " don't exists.";
    }

    $controller->$callback(
        $controller->ok_ko(
            {
                ok => \@ok,
                ko => \@ko
            }
        ),
        200
    );
}

sub delete_all_events_from_a_publisher {
    my ($controller, $arguments, $callback) = @_;

    my (@ok, @ko);

    my $publisher = $controller->scheduler()->{core}->publisher_by_name($arguments->{publisherName});

    if (defined $publisher) {
        $publisher->clear_queue();

        push @ok, 'clearing queue for publisher ' . $publisher->{definition}->{name} . '.';
    } else {
        push @ko, 'publisher ' . $arguments->{publisherName} . " don't exists.";
    }

    $controller->$callback(
        $controller->ok_ko(
            {
                ok => \@ok,
                ko => \@ko
            }
        ),
        200
    );
}

sub connect_or_disconnect_publisher {
    my ($controller, $arguments, $callback) = @_;

    my (@ok, @ko);

    my $publisher = $controller->scheduler()->{core}->publisher_by_name($arguments->{publisherName});

    if (defined $publisher) {
        if ($arguments->{publisherAction} eq 'connect' || $arguments->{publisherAction} eq 'disconnect') {
            my $method = $arguments->{publisherAction} . '_publisher_by_name';

            push @ok, $arguments->{publisherAction} . 'ing publisher ' . $publisher->{definition}->{name} . '.';

            $controller->scheduler()->{core}->$method($publisher->{definition}->{name});
        }
    } else {
        push @ko, 'publisher ' . $arguments->{publisherName} . " don't exists.";
    }

    $controller->$callback(
        $controller->ok_ko(
            {
                ok => \@ok,
                ko => \@ko
            }
        ),
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

Navel::Scheduler::Mojolicious::Application::Controller::Publisher

=head1 AUTHOR

Yoann Le Garff, Nicolas Boquet and Yann Le Bras

=head1 LICENSE

GNU GPL v3

=cut
