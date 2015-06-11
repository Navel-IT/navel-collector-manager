# Copyright 2015 Navel-IT
# Navel Scheduler is developped by Yoann Le Garff, Nicolas Boquet and Yann Le Bras under GNU GPL v3

#-> BEGIN

#-> initialization

package Navel::Scheduler::Cron::Exec;

use strict;
use warnings;

use parent qw/
    Navel::Base
/;

use File::Slurp;

use Navel::RabbitMQ::Serialize::Data qw/
    to
/;

use Navel::Utils qw/
    :all
/;

our $VERSION = 0.1;

#-> methods

sub new {
    my ($class, $connector, $logger) = @_;

    if (blessed($connector) eq 'Navel::Definition::Connector' && blessed($logger) eq 'Navel::Logger') {
        my $self = {
            __datas => undef,
            __connector => $connector,
            __logger => $logger
        };

        my $connector_generic_failed_message = 'Execution of connector ' . $connector->get_name() . ' failed';

        if ($connector->is_type_json()) {
            $self->{__exec} = sub {
                my $self = shift;

                local $@;

                my $datas = eval {
                    read_file($self->get_connector()->get_exec_file_path());
                };

                $self->get_logger()->bad($connector_generic_failed_message . ' : ' . $@ . '.', 'err')->flush_queue(1) if ($@);

                return $datas;
            };
        }

        $class = ref $class || $class;

        return bless $self, $class;
    }

    croak('One or more objects are invalids.');
}

sub exec {
    my $self = shift;

    $self->get_logger()->push_to_queue('Execution of connector ' . $self->get_connector()->get_name() . '.', 'info')->flush_queue(1);

    return $self->set_datas($self->get_exec()->($self));
}

sub serialize {
    my $self = shift;

    my $generic_message = 'Get and serialize datas for connector ' . $self->get_connector()->get_name();

    my $serialize = to(
        $self->get_connector(),
        $self->get_datas()
    );

    if ($serialize->[0]) {
        $self->get_logger()->good($generic_message . '.', 'info')->flush_queue(1);

        return $serialize->[1];
    }

    $self->get_logger()->bad($generic_message . ' failed.', 'err')->flush_queue(1);

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

sub get_logger {
    return shift->{__logger};
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
