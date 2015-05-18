# Copyright 2015 Navel-IT
# Navel Scheduler is developped by Yoann Le Garff, Nicolas Boquet and Yann Le Bras under GNU GPL v3

#-> BEGIN

#-> initialization

package Navel::Scheduler::Cron::Exec;

use strict;
use warnings;

use constant {
    FM_DEFAULT_MAX_PROCS => 10
};

use parent qw/
    Navel::Base
/;

use Scalar::Util::Numeric qw/
    isint
/;

use IO::File;

use IPC::Cmd qw/
    run
/;

use Parallel::ForkManager;

use Net::RabbitMQ;

use Navel::RabbitMQ::Serialize::Data qw/
    to
/;

use Navel::Utils qw/
    :all
/;

our $VERSION = 0.1;

#-> methods

sub new {
    my ($class, $connector, $rabbitmq, $extra_parameters) = @_;

    if (blessed($connector) eq 'Navel::Definition::Connector' && blessed($rabbitmq) eq 'Navel::Definition::RabbitMQ::Etc::Parser') {
        my $self = {
            __datas => undef,
            __connector => $connector,
            __rabbitmq => $rabbitmq,
            __max_procs => isint($extra_parameters->{max_procs}) ? $extra_parameters->{max_procs} : FM_DEFAULT_MAX_PROCS
        };

        if ($connector->is_type_code()) {
            $self->{__exec} = sub { # error to manage and log (eval require and eval { connector() }
                local $@;

                my $datas;

                if (eval "require '" . $connector->get_exec_file_path() . "'") {
                    $datas = eval {
                        connector($connector->get_properties());
                    };
                }

                return $datas;
            };
        } elsif ($connector->is_type_external()) {
            $self->{__exec} = sub {
                my ($cr, $error, $buffer, $bufferout, $buffererr) = run(
                    command => $connector->get_exec_file_path()
                );

                # $cr # error to manage and log

                return join '', @{$bufferout};
            };
        } elsif ($connector->is_type_plain_text()) {
            $self->{__exec} = sub { # error to manage and log if open() failed
                my $datas;

                my $fh = IO::File->new();

                $fh->binmode(':encoding(UTF-8)');

                if ($fh->open('< ' . $connector->get_exec_file_path())) {
                    local $/;

                    $datas = <$fh>;

                    $fh->close();
                }

                return $datas;
            };
        }

        $class = ref $class || $class;

        return bless $self, $class;
    }

    croak('Object(s) invalid(s).');
}

sub exec {
    my $self = shift;

    return $self->set_datas($self->get_exec()->());
}

sub push {
    my $self = shift;

    my $serialize = to(
        $self->get_connector(),
        $self->get_datas()
    );
    
    print $serialize->[1] . "\n";

    # if ($serialize->[0]) {
        # my $fm = Parallel::ForkManager->new(10); # general.json

        # for my $rabbitmq (@{$self->get_rabbitmq()->get_definitions()}) {
            # $fm->start() && next;

            # my $pusher = Net::RabbitMQ->new();

            # eval {
                # if ($pusher->connect(
                    # $rabbitmq->get_host(),
                    # {
                        # user => $rabbitmq->get_user(),
                        # password => $rabbitmq->get_password(),
                        # port => $rabbitmq->get_port(),
                        # vhost => $rabbitmq->get_vhost(),
                        # timeout => $rabbitmq->get_timeout()
                    # }
                # )) {
                    # $pusher->channel_open($rabbitmq->get_channel());

                    # $pusher->publish(
                        # $rabbitmq->get_channel(),
                        # 'cli.' . $self->get_connector()->get_name() . 'event',
                        # $serialize->[1]
                    # );

                    # $pusher->disconnect();
                # }
            # };

            # print $@ . "\n";

            # $fm->finish();
        # }

        # return $fm->wait_all_children();
    # }

    return 0;
}

sub set_datas {
    my ($self, $datas) = @_;

    $self->{__datas} = $datas;

    return $self;
}

sub get_datas {
    return shift->{__datas};
}

sub get_connector {
    return shift->{__connector};
}

sub get_rabbitmq {
    return shift->{__rabbitmq};
}

sub get_max_procs {
    return shift->{__max_procs};
}

sub get_exec {
    return shift->{__exec};
}

# sub AUTOLOAD {}

# sub DESTROY {}

1;

#-> END

__END__

=pod

=head1 NAME

Navel::Scheduler::Cron::Exec

=head1 AUTHOR

Yoann Le Garff, Nicolas Boquet and Yann Le Bras

=head1 LICENSE

GNU GPL v3

=cut