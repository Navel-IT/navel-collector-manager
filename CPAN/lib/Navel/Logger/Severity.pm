# Copyright 2015 Navel-IT
# Navel Scheduler is developed by Yoann Le Garff, Nicolas Boquet and Yann Le Bras under GNU GPL v3

#-> BEGIN

#-> initialization

package Navel::Logger::Severity;

use strict;
use warnings;

use parent 'Navel::Base';

use Carp 'croak';

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

    croak('severity must be defined') unless (defined $severity);
    croak('severity ' . $severity . ' is invalid') unless (exists $severities{$severity});

    bless {
        __severity => $severity
    }, ref $class || $class;
}

sub does_it_log {
    my ($self, $severity) = @_;

    defined $severity && exists $severities{$severity} && $severities{$self->get_severity()} >= $severities{$severity};
}

sub get_severity {
    shift->{__severity};
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