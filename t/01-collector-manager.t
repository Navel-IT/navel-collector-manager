# Copyright (C) 2015-2017 Yoann Le Garff, Nicolas Boquet and Yann Le Bras
# navel-collector-manager is licensed under the Apache License, Version 2.0

#-> BEGIN

#-> initialization

use strict;
use warnings;

use Test::More tests => 4;
use Test::Exception;
use Test::Mojo;

BEGIN {
    use_ok('Navel::CollectorManager');
    use_ok('Navel::Logger');
}

#-> main

my $meta_configuration_file_path = 't/01-meta.json';

my ($collector_manager, $mojolicious_tester);

lives_ok {
    $collector_manager = Navel::CollectorManager->new(
        logger => Navel::Logger->new(
            facility => 'local0',
            severity => 'debug'
        ),
        meta_configuration_file_path => $meta_configuration_file_path,
        webservice_listeners => [
            'http://*:8080'
        ]
    );
} 'Navel::CollectorManager->new: loading and preparing meta configuration from ' . $meta_configuration_file_path;

lives_ok {
    $mojolicious_tester = Test::Mojo->new(
        $collector_manager->{webserver}->app
    );
}

#-> END

__END__
