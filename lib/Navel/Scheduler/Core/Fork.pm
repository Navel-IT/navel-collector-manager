# Copyright 2015 Navel-IT
# navel-scheduler is developed by Yoann Le Garff, Nicolas Boquet and Yann Le Bras under GNU GPL v3

#-> BEGIN

#-> initialization

package Navel::Scheduler::Core::Fork 0.1;

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

    croak('core class is invalid') unless blessed($options{core}) && $options{core}->isa('Navel::Scheduler::Core');

    croak('collector definition is invalid') unless blessed($options{collector}) && $options{collector}->isa('Navel::Definition::Collector');

    my $self = bless {
        core => $options{core},
        collector => $options{collector}
    }, ref $class || $class;

    my $collector_basename = $self->{collector}->resolve_basename();

    my $collector_content .= "package Navel::Scheduler::Core::Fork::Worker;

BEGIN {
    CORE::open STDIN, '</dev/null';
    CORE::open STDOUT, '>/dev/null';
    CORE::open STDERR, '>&STDOUT';
}

sub event(\$\$) {
    AnyEvent::Fork::RPC::event(
        " . EVENT_EVENT . ',
        @_
    )
}

sub log($$) {
    AnyEvent::Fork::RPC::event(
        ' . EVENT_LOG . ',
        @_
    )
}

sub collect {
    local $@;

' . ($self->{collector}->{async} ? '
    my $done = $_[0];
' : '' ) . '
';

    if ($self->{core}->{configuration}->{definition}->{collectors}->{execution_timeout}) {
        $collector_content .= '    local $SIG{ALRM}' . " = sub {
        Navel::Scheduler::Core::Fork::Worker::log(
            'warning',
            'execution timeout after " . $self->{core}->{configuration}->{definition}->{collectors}->{execution_timeout} . "s.'
        );

        " . ($self->{collector}->{async} ? '$done->()' : 'CORE::exit') . ";
    };

    CORE::alarm " . $self->{core}->{configuration}->{definition}->{collectors}->{execution_timeout} . ";

";
    }

    $collector_content .= "    Navel::Scheduler::Core::Fork::Worker::log(
        'debug',
        'running with pid ' . \$\$ . '.'
    );

    eval {
";

    if ($self->{collector}->is_type_pm()) {
        $collector_content .= '         require ' . $collector_basename . ';';
    } else {
        if (defined $options{collector_content}) {
            $options{collector_content} =~ s/(^|\G)/            /gm;

            chomp $options{collector_content};

            $collector_content .= '        package main {
            #-> slurped code

' . $options{collector_content} . '

            #-< slurped code
        };';
        } else {
            $self->{core}->{logger}->warn('collector ' . $self->{collector}->{name} . ' is empty.');
        }
    }

    chomp $collector_content;


    my $collect_namespace = $self->{collector}->is_type_pm() ? $collector_basename : 'main';

    $collector_content .= '
    };

    unless ($@) {
        if (' . $collect_namespace . "->can('collect')) {
            " . $collect_namespace . "::collect(\@_);
        } else {
            Navel::Scheduler::Core::Fork::Worker::log(
                'err',
                'the mandatory subroutine " . $collect_namespace  . "::collect() is not declared.'
            );

            " . ($self->{collector}->{async} ? '$done->()' : '') . ';
        }
    } else {
        Navel::Scheduler::Core::Fork::Worker::log(
            "err",
            "an error occured while loading the collector : $@."
        );

        ' . ($self->{collector}->{async} ? '$done->()' : '') . ';
    }

    CORE::return;
}';

    $self->{core}->{logger}->debug(
        Navel::Logger::Message->stepped_message('dump of the source of the collector wrapper for ' . $self->{collector}->{name} . '.',
            [
                split /\n/, $collector_content
            ]
        )
    );

    $self->{rpc} = (blessed($options{ae_fork}) && $options{ae_fork}->isa('AnyEvent::Fork') ? $options{ae_fork} : AnyEvent::Fork->new())->fork()->eval($collector_content)->AnyEvent::Fork::RPC::run(
        'Navel::Scheduler::Core::Fork::Worker::collect',
        async => $self->{collector}->{async},
        on_event => $options{on_event},
        on_error => $options{on_error},
        on_destroy => $options{on_destroy},
        serialiser => Navel::AnyEvent::Fork::RPC::Serializer::Sereal::SERIALIZER
    );

    $self;
}

sub when_done {
    my ($self, %options) = @_;

    if (defined $self->{rpc}) {
        $self->{rpc}->(
            $self->{core}->{configuration}->{definition}->{collectors},
            $self->{collector}->properties(),
            $options{callback}
        );

        $self->{core}->{logger}->debug('spawned a new process for collector ' . $self->{collector}->{name} . '.');

        undef $self->{rpc};
    }

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

Navel::Scheduler::Core::Fork

=head1 AUTHOR

Yoann Le Garff, Nicolas Boquet and Yann Le Bras

=head1 LICENSE

GNU GPL v3

=cut
