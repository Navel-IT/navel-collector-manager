# Copyright (C) 2015 Yoann Le Garff, Nicolas Boquet and Yann Le Bras
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

use Navel::Logger::Message;
use Navel::AnyEvent::Fork::RPC::Serializer::Sereal;

use Navel::Utils qw/
    blessed
    croak
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
            definition => $options{definition},
            collector_content => $options{collector_content}
        }, $class;
    }

    my $wrapped_code = $self->wrapped_code();

    my $collector_basename = $self->{definition}->resolve_basename();

    $self->{core}->{logger}->debug(
        Navel::Logger::Message->stepped_message('dump of the source of the collector wrapper for ' . $collector_basename . '/' . $self->{definition}->{name} . '.',
            [
                split /\n/, $wrapped_code
            ]
        )
    );

    $self->{rpc} = (blessed($options{ae_fork}) && $options{ae_fork}->isa('AnyEvent::Fork') ? $options{ae_fork} : AnyEvent::Fork->new())->fork()->eval($wrapped_code)->AnyEvent::Fork::RPC::run(
        'Navel::Scheduler::Core::Collector::Fork::Worker::run',
        async => $self->{definition}->{async},
        on_event => $options{on_event},
        on_error => $options{on_error},
        on_destroy => $options{on_destroy},
        serialiser => Navel::AnyEvent::Fork::RPC::Serializer::Sereal::SERIALIZER
    );

    $self->{core}->{logger}->info('spawned a new process for collector ' . (ref $options{definition}) . '.' . $self->{definition}->{name} . '.');

    $self;
}

sub rpc {
    my ($self, %options) = @_;

    if (defined $self->{rpc}) {
        $self->{rpc}->(
            $options{exit},
            $self->{core}->{configuration}->{definition}->{collectors},
            $self->{definition}->properties(),
            ref $options{callback} eq 'CODE' ? $options{callback} : sub {}
        );
    }

    $self;
}

sub wrapped_code {
    my $self = shift;

    my $collector_basename = $self->{definition}->resolve_basename();

    my $wrapped_code .= "package Navel::Scheduler::Core::Collector::Fork::Worker;

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
                    @{$_}
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

        my $exit = shift;

        local $@;

';

    if ($self->{definition}->{async}) {
        $wrapped_code .= '        if ($Navel::Scheduler::Core::Collector::Fork::Worker::stopping) {
            $done->();

            return;
        }

        if ($exit) {
            $Navel::Scheduler::Core::Collector::Fork::Worker::stopping = 1;

            $done->();

            exit;
        }

';
    }

    if ($self->{core}->{configuration}->{definition}->{collectors}->{execution_timeout} && ! $self->{definition}->{async}) {
        $wrapped_code .= '        local $SIG{ALRM}' . " = sub {
            Navel::Scheduler::Core::Collector::Fork::Worker::log(
                [
                    'warning',
                    'execution timeout after " . $self->{core}->{configuration}->{definition}->{collectors}->{execution_timeout} . "s.'
                ]
            );

            exit;';
        };

        alarm " . $self->{core}->{configuration}->{definition}->{collectors}->{execution_timeout} . ";

";
    }

    $wrapped_code .= '        eval {
';

    if ($self->{definition}->is_type_pm()) {
        $wrapped_code .= '            require ' . $collector_basename . ';';
    } else {
        if (defined (my $collector_content = $self->{collector_content})) {
            $collector_content =~ s/(^|\G)/                /gm;

            chomp $collector_content;

            $wrapped_code .= '            package main {
                #-> slurped code

' . $collector_content . '

                #-< slurped code
            };';
        } else {
            $self->{core}->{logger}->warn('collector ' . $self->{definition}->{name} . ' is empty.');
        }
    }

    chomp $wrapped_code;

    my $collect_subroutine_namespace = $self->{definition}->is_type_pm() ? $collector_basename : 'main';

    $wrapped_code .= '
        };

        unless ($@) {
            if (' . $collect_subroutine_namespace . "->can('collect')) {
                " . $collect_subroutine_namespace . '::collect(' . ($self->{definition}->{async} ? '$done, ' : '') . "\@_);
            } else {
                Navel::Scheduler::Core::Collector::Fork::Worker::log(
                    [
                        'emerg',
                        'the mandatory subroutine " . $collect_subroutine_namespace  . "::collect() is not declared.'
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

# sub DESTROY {}

1;

#-> END

__END__

=pod

=encoding utf8

=head1 NAME

Navel::Scheduler::Core::Collector::Fork

=head1 COPYRIGHT

Copyright (C) 2015 Yoann Le Garff, Nicolas Boquet and Yann Le Bras

=head1 LICENSE

navel-scheduler is licensed under the Apache License, Version 2.0

=cut
