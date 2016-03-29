# Copyright 2015 Navel-IT
# navel-scheduler is developed by Yoann Le Garff, Nicolas Boquet and Yann Le Bras under GNU GPL v3

#-> BEGIN

#-> initialization

package Navel::Scheduler::Core::Fork 0.1;

use Navel::Base;

use AnyEvent::Fork;
use AnyEvent::Fork::RPC;

use Navel::AnyEvent::Fork::RPC::Serializer::Sereal;

use Navel::Utils qw/
    blessed
    croak
/;

#-> methods

sub new {
    my ($class, %options) = @_;

    croak('collector definition is invalid') unless blessed($options{collector}) && $options{collector}->isa('Navel::Definition::Collector');

    my $self = bless {
        core => $options{core},
        collector_execution_timeout => $options{collector_execution_timeout} || 0,
        collector => $options{collector},
        collector_content => $options{collector_content},
        ae_fork => blessed($options{ae_fork}) && $options{ae_fork}->isa('AnyEvent::Fork') ? $options{ae_fork} : AnyEvent::Fork->new()
    }, ref $class || $class;

    my $collector_basename = $self->{collector}->resolve_basename();

    my $collector_init_content .= '
BEGIN {
    open STDIN, "</dev/null";
    open STDOUT, ">/dev/null";
    open STDERR, ">&STDOUT";
}
';

    $collector_init_content .= 'use ' . $collector_basename . ';' if $self->{collector}->is_type_package();

    if ($self->{collector_execution_timeout}) {
        $collector_init_content .= '
$SIG{ALRM}' . " = sub {
    AnyEvent::Fork::RPC::event(
        [
            'warning',
            'execution timeout after " . $self->{collector_execution_timeout} . "s.'
        ]
    );

    exit;
};

alarm '" . $self->{collector_execution_timeout} . "';
";
    }

    $collector_init_content .= $self->{collector_content} unless $self->{collector}->is_type_package();

    $self->{rpc} = $self->{ae_fork}->fork()->eval($collector_init_content . "
sub __collect {
    AnyEvent::Fork::RPC::event(
        [
            'debug',
            'collector " . $self->{collector}->{name} . " running with pid ' . \$\$ . '.'
        ]
    );

    " . ($self->{collector}->is_type_package() ? $collector_basename . '::' : '') . 'collect(@_);
}'
    )->AnyEvent::Fork::RPC::run(
        '__collect',
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
