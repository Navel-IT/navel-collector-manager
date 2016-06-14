# Copyright (C) 2015 Yoann Le Garff, Nicolas Boquet and Yann Le Bras
# navel-scheduler is licensed under the Apache License, Version 2.0

#-> BEGIN

#-> initialization

package Navel::Scheduler::Mojolicious::Application::Controller::Swagger2::Collector 0.1;

use Navel::Base;

use Mojo::Base 'Mojolicious::Controller';

use Mojo::JSON 'decode_json';

#-> methods

sub list_collectors {
    my ($controller, $arguments, $callback) = @_;

    $controller->$callback(
        $controller->daemon()->{core}->{collectors}->name(),
        200
    );
}

sub new_collector {
    my ($controller, $arguments, $callback) = @_;

    my (@ok, @ko);

    local $@;

    my $body = eval {
        decode_json($controller->req()->body());
    };

    unless ($@) {
        if (ref $body eq 'HASH') {
            return $controller->resource_already_exists(
                {
                    callback => $callback,
                    resource_name => $body->{name}
                }
            ) if defined $controller->daemon()->{core}->{collectors}->definition_by_name($body->{name});

            my $collector = eval {
                $controller->daemon()->{core}->{collectors}->add_definition($body);
            };

            unless ($@) {
                $controller->daemon()->{core}->register_collector_by_name($collector->{name});

                push @ok, $collector->full_name() . ' added.';
            } else {
                push @ko, $@;
            }
        } else {
            push @ko, 'the request payload must represent a hash.';
        }
    } else {
        push @ko, $@;
    }

    $controller->$callback(
        $controller->ok_ko(\@ok, \@ko),
        @ko ? 400 : 201
    );
}

sub show_collector {
    my ($controller, $arguments, $callback) = @_;

    my $collector = $controller->daemon()->{core}->{collectors}->definition_properties_by_name($arguments->{collectorName});

    return $controller->resource_not_found(
        {
            callback => $callback,
            resource_name => $arguments->{collectorName}
        }
    ) unless defined $collector;

    $controller->$callback(
        $collector,
        200
    );
}

sub modify_collector {
    my ($controller, $arguments, $callback) = @_;

    my (@ok, @ko);

    local $@;

    my $body = eval {
        decode_json($controller->req()->body());
    };

    unless ($@) {
        if (ref $body eq 'HASH') {
            my $collector = $controller->daemon()->{core}->{collectors}->definition_by_name($arguments->{collectorName});

            return $controller->resource_not_found(
                {
                    callback => $callback,
                    resource_name => $arguments->{collectorName}
                }
            ) unless defined $collector;

            delete $body->{name};

            $body = {
                %{$collector->properties()},
                %{$body}
            };

            unless (my @validation_errors = @{$collector->validate($body)}) {
                eval {
                    $controller->daemon()->{core}->delete_collector_and_definition_associated_by_name($body->{name});
                };

                unless ($@) {
                    my $collector = eval {
                        $controller->daemon()->{core}->{collectors}->add_definition($body);
                    };

                    unless ($@) {
                        $controller->daemon()->{core}->register_collector_by_name($collector->{name});

                        push @ok, $collector->full_name() . ' modified.';
                    } else {
                        push @ko, $@;
                    }
                } else {
                    push @ko, 'an unknown eror occurred while modifying the collector ' . $body->{name} . '.';
                }
            } else {
                push @ko, 'error(s) occurred while modifying collector ' . $body->{name} . ':', \@validation_errors;
            }
        } else {
            push @ko, 'the request payload must represent a hash.';
        }
    } else {
        push @ko, $@;
    }

    $controller->$callback(
        $controller->ok_ko(\@ok, \@ko),
        @ko ? 400 : 200
    );
}

sub delete_collector {
    my ($controller, $arguments, $callback) = @_;

    local $@;

    my $collector = $controller->daemon()->{core}->{collectors}->definition_by_name($arguments->{collectorName});

    return $controller->resource_not_found(
        {
            callback => $callback,
            resource_name => $arguments->{collectorName}
        }
    ) unless defined $collector;

    my (@ok, @ko);

    eval {
        $controller->daemon()->{core}->delete_collector_and_definition_associated_by_name($collector->{name});
    };

    unless ($@) {
        push @ok, $collector->full_name() . ': ' . ($collector->{async} ? 'killed, ' : '') . 'unregistered and deleted.';
    } else {
        push @ko, $@;
    }

    $controller->$callback(
        $controller->ok_ko(\@ok, \@ko),
        @ko ? 400 : 200
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

Navel::Scheduler::Mojolicious::Application::Controller::Swagger2::Collector

=head1 COPYRIGHT

Copyright (C) 2015 Yoann Le Garff, Nicolas Boquet and Yann Le Bras

=head1 LICENSE

navel-scheduler is licensed under the Apache License, Version 2.0

=cut
