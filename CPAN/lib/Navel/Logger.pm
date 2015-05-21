# Copyright 2015 Navel-IT
# Navel Scheduler is developped by Yoann Le Garff, Nicolas Boquet and Yann Le Bras under GNU GPL v3

#-> BEGIN

#-> initialization

package Navel::Logger;

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

use Navel::Utils qw/
    :all
/;

our $VERSION = 0.1;

#-> methods

sub new {
    my ($class, $file_path) = @_;

    my $self = {
        __file_path => $file_path,
        __buffer => []
    };

    if (defined $self->{__file_path}) {
        $self->{__filehandler} = IO::File->new();

        $self->{__filehandler}->binmode(':encoding(UTF-8)');

        $self->{__filehandler} = undef unless $self->{__filehandler}->open('>> ' . $self->{__file_path});
    }

    $self->{__filehandler} ||= *STDOUT;

    $class = ref $class || $class;

    return bless $self, $class;
}

sub get_buffer {
    return shift->{__buffer};
}

sub push_to_buffer {
    my ($self, $messages) = @_;

    if (defined $messages) {
        $self->clear_buffer() if ($clear_buffer);

        if (ref $messages eq 'ARRAY') {
            for (@{$messages}) {
                $self->push_to_buffer(get_a_proper_localtime(time) . ' ' . crunch($_)) if (defined $_);
            }
        } else {
            push @{$self->get_buffer()}, get_a_proper_localtime(time) . ' ' . crunch($messages);
        }
    }

    return $self;
}

sub join_buffer {
    my ($self, $separator) = @_;

    return join $separator, @{$self->get_buffer()};
}

sub flush_buffer {
    my ($self, $clear_buffer) = @_;

    no strict qw/
        refs
    /;

    print { $self->__get_filehandler() } $self->join_buffer("\n") . "\n";

    return $clear_buffer ? $self->clear_buffer() : $self;
}

sub clear_buffer {
    my $self = shift;

    @{$self->get_buffer()} = ();

    return $self;
}

sub get_file_path {
    return shift->{__file_path};
}

sub __get_filehandler {
    return shift->{__filehandler};
}

sub __set_filehandler {
    shift->{__filehandler} = shift;
}

sub on_stdout {
    my $self = shift;

    $self->__set_filehandler(*STDOUT);

    return $self;
}

sub on_stderr {
    my $self = shift;

    $self->__set_filehandler(*STDERR);

    return $self;
}

sub is_filehandler_via_lib {
    return blessed(shift->__get_filehandler()) eq 'IO::File';
}

# sub AUTOLOAD {}

sub DESTROY {
    my $self = shift;

    $self->__get_filehandler()->close() if ($self->is_filehandler_via_lib());
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