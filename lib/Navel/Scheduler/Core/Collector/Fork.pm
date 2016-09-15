# Copyright (C) 2015-2016 Yoann Le Garff, Nicolas Boquet and Yann Le Bras
# navel-scheduler is licensed under the Apache License, Version 2.0

#-> BEGIN

#-> initialization

package Navel::Scheduler::Core::Collector::Fork 0.1;

use Navel::Base;

use constant {
    EVENT_EVENT => 0,
    EVENT_LOG => 1
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
        'Navel::Scheduler::Core::Collector::Fork::Worker::run',
        async => $self->{definition}->{async},
        on_event => $options{on_event},
        on_error => sub {
            undef $weak_self->{rpc};

            $options{on_error}->(@_);
        },
        on_destroy => $options{on_destroy},
        serialiser => Navel::AnyEvent::Fork::RPC::Serializer::Sereal::SERIALIZER
    );

    $self->{core}->{logger}->info($self->{definition}->full_name() . ': spawned a new process.');

    $self;
}

sub rpc {
    my $self = shift;

    my $deferred = deferred();

    if (defined $self->{rpc}) {
        $self->{rpc}->(
            shift // 'collect',
            $self->{core}->{meta}->{definition}->{collectors},
            $self->{definition}->properties(),
            sub {
                $deferred->resolve(@_);
            }
        );
    } else {
        $deferred->reject('the runtime is not ready');
    }

    $deferred->promise();
}

sub wrapped_code {
    my $self = shift;

    my $wrapped_code = "package Navel::Scheduler::Core::Collector::Fork::Worker;

{
    BEGIN {
        open STDIN, '</dev/null';
        open STDOUT, '>/dev/null';
        open STDERR, '>&STDOUT';
    }" . ($self->{definition}->{async} ? '

    our $stopping;' : '') . '

    sub event {
        AnyEvent::Fork::RPC::event(
            map {
                [
                    ' . EVENT_EVENT . ',
                    $_
                ]
            } @_
        );
    }

    sub log {
        AnyEvent::Fork::RPC::event(
            map {
                [
                    ' . EVENT_LOG . ',
                    @{$_}
                ]
            } @_
        );
    }
};

{
    sub run {' . ($self->{definition}->{async} ? '
        my $done = shift;' : '') . '

        my $action = shift;

        local $@;

';

    if ($self->{definition}->{async}) {
        $wrapped_code .= '        if ($Navel::Scheduler::Core::Collector::Fork::Worker::stopping) {
            $done->();

            return;
        }

        if ($action eq ' . "'exit'" . ') {
            $Navel::Scheduler::Core::Collector::Fork::Worker::stopping = 1;

            $done->();

            CORE::exit;
        }

';
    }

    if ($self->{definition}->{execution_timeout}) {
        $wrapped_code .= '        local $SIG{ALRM}' . " = sub {
            Navel::Scheduler::Core::Collector::Fork::Worker::log(
                [
                    'warning',
                    'execution timeout after " . $self->{definition}->{execution_timeout} . "s.'
                ]
            );" . ($self->{definition}->{async} ? '
            $done->();' : '') . '

            exit;
        };

        alarm ' . $self->{definition}->{execution_timeout} . ";

";
    }

    $wrapped_code .= '        eval {
            require ' . $self->{definition}->{backend} . ';
        };

        unless ($@) {
            if (my $action_sub = ' . $self->{definition}->{backend} . '->can($action)) {
                $action_sub->(' . ($self->{definition}->{async} ? '$done, ' : '') . "\@_);
            } else {
                Navel::Scheduler::Core::Collector::Fork::Worker::log(
                    [
                        'err',
                        'the subroutine " . $self->{definition}->{backend}  . "::' . \$action . '() is not declared.'
                    ]
                ); " . ($self->{definition}->{async} ? '

                $done->();' : '') . "
            }
        } else {
            Navel::Scheduler::Core::Collector::Fork::Worker::log(
                [
                    'emerg',
                    'an error occured while loading the collector: ' . \$@ . '.'
                ]
            ); " . ($self->{definition}->{async} ? '

            $done->();' : '') . '
        }

        return;
    }
};

1;';

    $wrapped_code;
}

# sub AUTOLOAD {}

sub DESTROY {
    my $self = shift;

    local $@;

    eval {
        $self->rpc('exit') if $self->{definition}->{async};

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
