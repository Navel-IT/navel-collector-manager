# Copyright 2015 Navel-IT
# Navel Scheduler is developped by Yoann Le Garff, Nicolas Boquet and Yann Le Bras under GNU GPL v3

#-> BEGIN

#-> initialization

use strict;
use warnings;

use Test::More;

BEGIN {
    use_ok('Navel::Definition::WebService::Etc::Parser');
}

#-> main

my $web_services_definitions_path = 't/02-webservices.json';

my $web_services_listeners = Navel::Definition::WebService::Etc::Parser->new();

my $return = $web_services_listeners->load($web_services_definitions_path);

if (ok($return->[0], 'load() : loading definition from ' . $web_services_definitions_path)) {
    my $return = $web_services_listeners->make();

    ok($return->[0], 'make() : making definitions');
}

done_testing();

#-> END

__END__