# Copyright (C) 2015-2017 Yoann Le Garff, Nicolas Boquet and Yann Le Bras
# navel-collector-manager is licensed under the Apache License, Version 2.0

#-> BEGIN

#-> initialization

package Navel::CollectorManager::Parser 0.1;

use Navel::Base;

use parent 'Navel::Base::Daemon::Parser';

use JSON::Validator::OpenAPI;

use Navel::API::OpenAPI::CollectorManager;

#-> methods

sub validate {
    my $class = shift;

    $class->SUPER::validate(
        raw_definition => shift,
        validator => sub {
            state $json_validator = JSON::Validator->new->schema(
                Navel::API::OpenAPI::CollectorManager->new->schema->get('/definitions/meta')
            );

            [
                $json_validator->validate(shift)
            ];
        }
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

Navel::CollectorManager::Parser

=head1 COPYRIGHT

Copyright (C) 2015-2017 Yoann Le Garff, Nicolas Boquet and Yann Le Bras

=head1 LICENSE

navel-collector-manager is licensed under the Apache License, Version 2.0

=cut
