# Copyright 2015 Navel-IT
# Navel Scheduler is developed by Yoann Le Garff, Nicolas Boquet and Yann Le Bras under GNU GPL v3

#-> BEGIN

#-> initialization

package Navel::Logger;

use 5.10.1;

use strict;
use warnings;

use parent 'Navel::Base';

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

use String::Util 'crunch';

use File::Slurp 'append_file';

use Navel::Logger::Severity;
use Navel::Utils 'human_readable_localtime';

our $VERSION = 0.1;

#-> globals

binmode STDOUT, ':utf8';

binmode STDERR, ':utf8';

#-> methods

sub new {
    my ($class, $default_severity, $severity, $file_path) = @_;

    bless {
        __severity => eval {
            Navel::Logger::Severity->new($severity)
        } || Navel::Logger::Severity->new($default_severity),
        __file_path => $file_path,
        __queue => []
    }, ref $class || $class;
}

sub get_severity {
    shift->{__severity};
}

sub get_file_path {
    shift->{__file_path};
}

sub get_queue {
    shift->{__queue};
}

sub push_in_queue { # need changes relatives to the comments below
    my ($self, $messages, $severity) = @_;

    push @{$self->get_queue()}, '[' . human_readable_localtime(time) . '] [' . $severity . '] ' . crunch($messages) if (defined $messages && $self->get_severity()->does_it_log($severity));

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

sub clear_queue {
    my $self = shift;

    undef @{$self->get_queue()};

    $self;
}

sub flush_queue {
    my ($self, $clear_queue) = @_;

    if (@{$self->get_queue()}) {
        if (defined $self->get_file_path()) {
            eval {
                append_file(
                    $self->get_file_path(),
                    {
                        binmode => ':utf8'
                    },
                    [
                        map { $_ . "\n" } @{$self->get_queue()}
                    ]
                );
            };
        } else {
            say $self->join_queue("\n");
        }
    }

    $clear_queue ? $self->clear_queue() : $self;
}

# sub AUTOLOAD {}

# sub DESTROY {}

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
