# Copyright (C) 2015 Yoann Le Garff, Nicolas Boquet and Yann Le Bras
# navel-scheduler is licensed under the Apache License, Version 2.0

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

=head1 COPYRIGHT

Copyright (C) 2015 Yoann Le Garff, Nicolas Boquet and Yann Le Bras

=head1 LICENSE

navel-scheduler is licensed under the Apache License, Version 2.0

=cut
