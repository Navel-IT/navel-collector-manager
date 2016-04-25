# Copyright 2015 Navel-IT
# navel-scheduler is developed by Yoann Le Garff, Nicolas Boquet and Yann Le Bras under GNU GPL v3

#-> BEGIN

#-> initialization

package t::lib::Navel::Broker::Client::Fork::Publisher::Backend::Dummy 0.1;

use Navel::Base;

#-> methods

sub is_connectable {
    1;
}

sub publish {
}

# sub AUTOLOAD {}

# sub DESTROY {}

1;

#-> END

__END__

=pod

=encoding utf8

=head1 NAME

t::lib::Navel::Broker::Client::Fork::Publisher::Backend::Dummy

=head1 AUTHOR

Yoann Le Garff, Nicolas Boquet and Yann Le Bras

=head1 LICENSE

GNU GPL v3

=cut
