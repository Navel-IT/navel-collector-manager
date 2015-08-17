# Copyright 2015 Navel-IT
# Navel Scheduler is developed by Yoann Le Garff, Nicolas Boquet and Yann Le Bras under GNU GPL v3

#-> BEGIN

#-> initialization

package Navel::Definition::WebService::Etc::Parser;

use strict;
use warnings;

use parent 'Navel::Base::Definition::Etc::Parser';

our $VERSION = 0.1;

#-> methods

sub new {
    shift->SUPER::new('Navel::Definition::WebService', 1);
}

sub get_interface_masks {
    shift->__get_all_by_getter('get_interface_mask');
}

sub get_ports {
    shift->__get_all_by_getter('get_port');
}

sub get_tls {
    shift->__get_all_by_getter('get_tls');
}

sub get_cas {
    shift->__get_all_by_getter('get_ca');
}

sub get_certs {
    shift->__get_all_by_getter('get_cert');
}

sub get_ciphers {
    shift->__get_all_by_getter('get_ciphers');
}

sub get_keys {
    shift->__get_all_by_getter('get_key');
}

sub get_verifies {
    shift->__get_all_by_getter('get_verify');
}

sub get_urls {
    shift->__get_all_by_getter('get_url');
}

# sub AUTOLOAD {}

# sub DESTROY {}

1;

#-> END

__END__

=pod

=head1 NAME

Navel::Definition::WebService::Etc::Parser

=head1 AUTHOR

Yoann Le Garff, Nicolas Boquet and Yann Le Bras

=head1 LICENSE

GNU GPL v3

=cut
