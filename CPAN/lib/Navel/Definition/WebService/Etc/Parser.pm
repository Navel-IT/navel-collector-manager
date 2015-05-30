# Copyright 2015 Navel-IT
# Navel Scheduler is developped by Yoann Le Garff, Nicolas Boquet and Yann Le Bras under GNU GPL v3

#-> BEGIN

#-> initialization

package Navel::Definition::WebService::Etc::Parser;

use strict;
use warnings;

use parent qw/
    Navel::Base::Definition::Etc::Parser
/;

use Navel::Utils qw/
    :all
/;

our $VERSION = 0.1;

#-> methods

sub make {
    return shift->SUPER::make('Navel::Definition::WebService', 0, shift);
}

sub get_interface_masks {
    return shift->__get_all_by_getter('get_interface_mask');
}

sub get_ports {
    return shift->__get_all_by_getter('get_port');
}

sub get_tls {
    return shift->__get_all_by_getter('get_tls');
}

sub get_logins {
    return shift->__get_all_by_getter('get_login');
}

sub get_passwords {
    return shift->__get_all_by_getter('get_password');
}

sub get_urls {
    return shift->__get_all_by_getter('get_url');
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
