# Copyright (C) 2015-2016 Yoann Le Garff, Nicolas Boquet and Yann Le Bras
# navel-scheduler is licensed under the Apache License, Version 2.0

#-> BEGIN

#-> initialization

package Navel::Scheduler::Core::Collector::Fork 0.1;

use Navel::Base;

use constant {
    WORKER_PACKAGE_NAME => 'Navel::Scheduler::Core::Collector::Fork::Worker',
    WORKER_RPC_METHOD_NAME => '_rpc'
};

use AnyEvent::Fork;
use AnyEvent::Fork::RPC;

use Promises 'deferred';

use Navel::Logger::Message;
use Navel::AnyEvent::Fork::RPC::Serializer::Sereal;

use Navel::Utils qw/
    blessed
    croak
    weaken
/;

#-> methods

sub new {
    my ($class, %options) = @_;

    my $self;

    if (ref $class) {
        $self = $class;
    } else {
        croak('core class is invalid') unless blessed($options{core}) && $options{core}->isa('Navel::Scheduler::Core');

        croak('collector definition is invalid') unless blessed($options{definition}) && $options{definition}->isa('Navel::Definition::Collector');

        $self = bless {
            core => $options{core},
            definition => $options{definition}
        }, $class;
    }

    my $weak_self = $self;

    weaken($weak_self);

    my $wrapped_code = $self->wrapped_code();

    $self->{core}->{logger}->debug(
        Navel::Logger::Message->stepped_message($self->{definition}->full_name() . ': dump of the source.',
            [
                split /\n/, $wrapped_code
            ]
        )
    );

    $self->{rpc} = (blessed($options{ae_fork}) && $options{ae_fork}->isa('AnyEvent::Fork') ? $options{ae_fork} : AnyEvent::Fork->new())->fork()->eval($wrapped_code)->AnyEvent::Fork::RPC::run(
        WORKER_PACKAGE_NAME . '::' . WORKER_RPC_METHOD_NAME,
        on_event => $options{on_event},
        on_error => sub {
            undef $weak_self->{rpc};

            $options{on_error}->(@_);
        },
        on_destroy => $options{on_destroy},
        async => 1,
        initialized => 0,
        serialiser => Navel::AnyEvent::Fork::RPC::Serializer::Sereal::SERIALIZER
    );

    $self->{core}->{logger}->info($self->{definition}->full_name() . ': spawned a new worker.');

    $self;
}

sub rpc {
    my $self = shift;

    my $deferred = deferred();

    if (defined $self->{rpc}) {
        my @definitions;

        unless ($self->{initialized}) {
            $self->{initialized} = 1;

            push @definitions, $self->{core}->{meta}, $self->{definition};
        }

        $self->{rpc}->(
            @_,
            @definitions,
            sub {
                shift ? $deferred->resolve(@_) : $deferred->reject(@_);
            }
        );
    } else {
        $deferred->reject('the worker is not ready');
    }

    $deferred->promise();
}

sub wrapped_code {
    my $self = shift;

    'package ' . WORKER_PACKAGE_NAME . " 0.1;

BEGIN {
    open STDIN, '</dev/null';
    open STDOUT, '>/dev/null';
    open STDERR, '>&STDOUT';
}" . '

use Navel::Base;

use Navel::Queue;
use Navel::Event;

require ' . $self->{definition}->{backend} . ';
require ' . $self->{definition}->{publisher}->{backend} . ';

my ($initialized, $exiting);

sub ' . WORKER_RPC_METHOD_NAME . ' {
    my ($done, $backend, $sub, $meta, $collector) = @_;

    if ($exiting) {
        $done->(0, ' . "'currently exiting the worker'" . ');

        return;
    }

    unless (defined $backend) {
        if ($sub eq ' . "'queue'" . ') {
            $done->(1, scalar @{queue()->{items}});
        } elsif ($sub eq ' . "'dequeue'" . ') {
            $done->(1, scalar queue()->dequeue());
        } else {
            $exiting = 1;

            $done->(1, ' . "'exiting the worker'" . ');

            exit;
        }

        return;
    }

    unless ($initialized) {
        $initialized = 1;

        *meta = sub {
            $meta;
        };

        *collector = sub {
            state $collector = Navel::Definition::Collector->new($collector);
        };

        *event = sub {
            map {
                Navel::Event->new(
                    collector => collector(),
                    data => $_
                )->serialize();
            } @_;
        };

        ' . $self->{definition}->{backend} . '->init();
        ' . $self->{definition}->{publisher}->{backend} . '->init();
    }

    if (my $sub_ref = $backend->can($sub)) {
        $sub_ref->($done);
    } else {
        $done->(0, ' . "\$backend . '::' . \$sub . '() is not declared'" . ');
    }

    return;
}

*log = \&AnyEvent::Fork::RPC::event;

sub queue {
    state $queue = Navel::Queue->new(
        auto_clean => ' . $self->{definition}->{publisher}->{auto_clean} . '
    );
}

1;';
}

# sub AUTOLOAD {}

sub DESTROY {
    my $self = shift;

    local $@;

    eval {
        $self->rpc();

        undef $self->{rpc};
    };

    $self;
}

1;

#-> END

__END__

=pod

=encoding utf8

=head1 NAME

Navel::Scheduler::Core::Collector::Fork

=head1 COPYRIGHT

Copyright (C) 2015-2016 Yoann Le Garff, Nicolas Boquet and Yann Le Bras

=head1 LICENSE

navel-scheduler is licensed under the Apache License, Version 2.0

=cut
