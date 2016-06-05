# Copyright (C) 2015 Yoann Le Garff, Nicolas Boquet and Yann Le Bras
# navel-scheduler is licensed under the Apache License, Version 2.0

#-> BEGIN

#-> initialization

use strict;
use warnings;

use Test::More tests => 4;
use Test::Exception;
use Test::Mojo;

BEGIN {
    use_ok('Navel::Scheduler');
    use_ok('Navel::Logger');
}

#-> main

my $main_configuration_file_path = 't/01-main.yml';

my ($scheduler, $mojolicious_tester);

lives_ok {
    $scheduler = Navel::Scheduler->new(
        logger => Navel::Logger->new(
            facility => 'local0',
            severity => 'debug'
        ),
        main_configuration_file_path => $main_configuration_file_path,
        enable_webservices => 1
    );
} 'Navel::Scheduler->new(): loading and preparing main configuration from ' . $main_configuration_file_path;

lives_ok {
    $mojolicious_tester = Test::Mojo->new(
        $scheduler->{webserver}->app()
    );
}

#-> END

__END__
