# Copyright 2015 Navel-IT
# navel-scheduler is developed by Yoann Le Garff, Nicolas Boquet and Yann Le Bras under GNU GPL v3

#-> BEGIN

#-> initialization

package Navel::Scheduler 0.1;

use Navel::Base;

use File::ShareDir 'dist_dir';

use Navel::Scheduler::Parser;
use Navel::Scheduler::Core;
use Navel::Definition::Collector::Parser;
use Navel::Definition::Publisher::Parser;
use Navel::Definition::WebService::Parser;
use Navel::Utils qw/
    croak
    blessed
/;

#-> methods

sub new {
    my ($class, %options) = @_;

    die "main configuration file path is missing\n" unless defined $options{main_configuration_file_path};

    bless {
        main_configuration_file_path => $options{main_configuration_file_path},
        configuration => Navel::Scheduler::Parser->new()->read(
            file_path => $options{main_configuration_file_path}
        ),
        core => undef,
        webservices => undef,
        web_server => undef
    }, ref $class || $class;
}

sub prepare {
    my ($self, %options) = @_;

    croak('logger option must be an object of the Navel::Logger class') unless blessed($options{logger}) && $options{logger}->isa('Navel::Logger');

    $self->{core} = Navel::Scheduler::Core->new(
        configuration => $self->{configuration},
        collectors => Navel::Definition::Collector::Parser->new(
            maximum => $self->{configuration}->{definition}->{collectors}->{maximum}
        )->read(
            file_path => $self->{configuration}->{definition}->{collectors}->{definitions_from_file}
        )->make(),
        publishers => Navel::Definition::Publisher::Parser->new(
            maximum => $self->{configuration}->{definition}->{publishers}->{maximum}
        )->read(
            file_path => $self->{configuration}->{definition}->{publishers}->{definitions_from_file}
        )->make(),
        logger => $options{logger}
    );

    if ($options{enable_webservices}) {
        $self->{webservices} = Navel::Definition::WebService::Parser->new()->read(
            file_path => $self->{configuration}->{definition}->{webservices}->{definitions_from_file}
        )->make();

        if (@{$self->{webservices}->{definitions}}) {
            require Navel::Scheduler::Mojolicious::Application;
            Navel::Scheduler::Mojolicious::Application->import();

            require Mojo::Server::Prefork;
            Mojo::Server::Prefork->import();

            my $mojolicious_app = Navel::Scheduler::Mojolicious::Application->new($self);

            $mojolicious_app->mode('production');

            my $mojolicious_app_home = dist_dir('Navel-Scheduler') . '/mojolicious/home';

            @{$mojolicious_app->renderer()->paths()} = ($mojolicious_app_home . '/templates');
            @{$mojolicious_app->static()->paths()} = ($mojolicious_app_home . '/public');

            $self->{web_server} = Mojo::Server::Prefork->new(
                app => $mojolicious_app,
                listen => $self->{webservices}->url()
            );
        }
    }

    $self;
}

sub start {
    my $self = shift;

    croak("scheduler isn't prepared") unless blessed($self->{core}) && $self->{core}->isa('Navel::Scheduler::Core');

    if ($self->{web_server}) {
        local $@;

        $self->{core}->{logger}->notice('starting the webservices.')->flush_queue();

        eval {
            while (my ($method, $value) = each %{$self->{configuration}->{definition}->{webservices}->{mojo_server}}) {
                $self->{web_server}->$method($value);
            }

            $self->{web_server}->silent(1)->start();
        };

        if ($@) {
            $self->{core}->{logger}->crit($self->{core}->{logger}->stepped_log($@))->flush_queue();
        } else {
            $self->{core}->{logger}->notice('webservices started.')->flush_queue();
        }
    }

    $self->{core}->register_logger_by_name(0)->register_collectors()->init_publishers()->register_publishers()->recv();

    $self;
}

sub stop {
    my $self = shift;

    $self->{web_server}->stop() if defined $self->{web_server};

    $self->{core}->send();

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

=head1 AUTHOR

Yoann Le Garff, Nicolas Boquet and Yann Le Bras

=head1 LICENSE

GNU GPL v3

=cut
