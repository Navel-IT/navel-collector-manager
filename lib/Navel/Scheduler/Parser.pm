# Copyright (C) 2015 Yoann Le Garff, Nicolas Boquet and Yann Le Bras
# navel-scheduler is licensed under the Apache License, Version 2.0

#-> BEGIN

#-> initialization

package Navel::Scheduler::Parser 0.1;

use Navel::Base;

use parent 'Navel::Base::Daemon::Parser';

use JSON::Validator;

use Navel::API::Swagger2::Scheduler;

#-> methods

sub json_validator {
    my $class = shift;

    state $json_validator = JSON::Validator->new()->schema(
        Navel::API::Swagger2::Scheduler->new()->expand()->api_spec()->get('/definitions/meta')
    );
}

sub validate {
    my ($class, $raw_definition) = @_;

    $class->SUPER::validate(
        @_,
        raw_definition => $raw_definition
    );
}

# sub AUTOLOAD {}

# sub DESTROY {}

1;

#-> END

__END__

=pod

=encoding utf8

=head1 NAME

Navel::Scheduler::Parser

=head1 COPYRIGHT

Copyright (C) 2015 Yoann Le Garff, Nicolas Boquet and Yann Le Bras

=head1 LICENSE

navel-scheduler is licensed under the Apache License, Version 2.0

=cut
