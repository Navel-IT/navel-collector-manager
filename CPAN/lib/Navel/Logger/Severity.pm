# Copyright 2015 Navel-IT
# Navel Scheduler is developed by Yoann Le Garff, Nicolas Boquet and Yann Le Bras under GNU GPL v3

#-> BEGIN

#-> initialization

package Navel::Logger::Severity;

use strict;
use warnings;

use parent qw/
    Navel::Base
/;

use Carp qw/
    carp
    croak
/;

use Navel::Utils qw/
    :all
/;

our $VERSION = 0.1;

#-> class variables

my %severities = (
    emerg => 0,
    alert => 1,
    crit => 2,
    err => 3,
    warn => 4,
    notice => 5,
    info => 6,
    debug => 7
);

#-> methods

sub new {
    my ($class, $severity) = @_;

    if (defined $severity) {
        if (exists $severities{$severity}) {
            $class = ref $class || $class;

            return bless {
                __severity => $severity
            }, $class;
        }

        croak('severity ' . $severity . ' is incorrect');
    }

    croak('severity must be defined');
}

sub does_it_log {
    my ($self, $severity) = @_;

    return defined $severity && exists $severities{$severity} && $severities{$self->get_severity()} >= $severities{$severity};
}

sub get_severity {
    return shift->{__severity};
}

# sub AUTOLOAD {}

# sub DESTROY {}

1;

#-> END

__END__

=pod

=head1 NAME

Navel::Logger::Severity

=head1 AUTHOR

Yoann Le Garff, Nicolas Boquet and Yann Le Bras

=head1 LICENSE

GNU GPL v3

=cut