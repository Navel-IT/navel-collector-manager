# Copyright 2015 Navel-IT
# Navel Scheduler is developed by Yoann Le Garff, Nicolas Boquet and Yann Le Bras under GNU GPL v3

#-> BEGIN

#-> initialization

package Navel::Logger;

use 5.10.1;

use strict;
use warnings;

use parent qw/
    Navel::Base
/;

use Exporter::Easy (
    OK => [qw/
        $VERSION
        :all
    /],
    TAGS => [
        all => [qw/
            $VERSION
        /]
    ]
);

use String::Util qw/
    crunch
/;

use IO::File;

use Navel::Logger::Severity;

use Navel::Utils qw/
    :all
/;

our $VERSION = 0.1;

#-> global

binmode STDOUT, ':utf8';

binmode STDERR, ':utf8';

#-> methods

sub new {
    my ($class, $default_severity, $file_path, $severity) = @_;

    local $!;

    my $self = {
        __severity => eval {
            Navel::Logger::Severity->new($severity)
        } || Navel::Logger::Severity->new($default_severity),
        __file_path => $file_path,
        __queue => []
    };

    if (defined $self->{__file_path}) {
        $self->{__filehandler} = IO::File->new();

        $self->{__filehandler}->binmode(':utf8');

        $self->{__filehandler} = undef unless $self->{__filehandler}->open('>> ' . $self->{__file_path});
    }

    $self->{__filehandler} ||= *STDOUT;

    bless $self, ref $class || $class;
}

sub get_severity {
    shift->{__severity};
}

sub get_file_path {
    shift->{__file_path};
}

sub get_filehandler {
    shift->{__filehandler};
}

sub __set_filehandler {
    shift->{__filehandler} = shift;
}

sub on_stdout {
    my $self = shift;

    $self->__set_filehandler(*STDOUT);

    $self;
}

sub on_stderr {
    my $self = shift;

    $self->__set_filehandler(*STDERR);

    $self;
}

sub is_filehandler_via_lib {
    blessed(shift->get_filehandler()) eq 'IO::File';
}

sub get_queue {
    shift->{__queue};
}

sub push_in_queue { # need changes relatives to the comments below
    my ($self, $messages, $severity) = @_;

    push @{$self->get_queue()}, '[' . get_a_proper_localtime(time) . '] [' . $severity . '] ' . crunch($messages) if (defined $messages && $self->get_severity()->does_it_log($severity));

    $self;
}

sub good { # need to switch to STDOUT when ! $fh->isa('IO::File')
    shift->push_in_queue('[OK] ' . shift, shift);
}

sub bad { # need to switch to STDERR when ! $fh->isa('IO::File')
    shift->push_in_queue('[KO] ' . shift, shift);
}

sub join_queue {
    my ($self, $separator) = @_;

    join $separator, @{$self->get_queue()};
}

sub flush_queue {
    my ($self, $clear_queue) = @_;

    no strict qw/
        refs
    /;

    say { $self->get_filehandler() } $self->join_queue("\n") if (@{$self->get_queue()});

    $clear_queue ? $self->clear_queue() : $self;
}

sub clear_queue {
    my $self = shift;

    undef @{$self->get_queue()};

    $self;
}

# sub AUTOLOAD {}

sub DESTROY {
    my $self = shift;

    local $!;

    $self->get_filehandler()->close() if ($self->is_filehandler_via_lib());
}

1;

#-> END

__END__

=pod

=head1 NAME

Navel::Logger

=head1 AUTHOR

Yoann Le Garff, Nicolas Boquet and Yann Le Bras

=head1 LICENSE

GNU GPL v3

=cut
