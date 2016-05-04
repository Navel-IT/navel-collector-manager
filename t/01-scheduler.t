# Copyright (C) 2015 Yoann Le Garff, Nicolas Boquet and Yann Le Bras
# navel-scheduler is licensed under the Apache License, Version 2.0

#-> BEGIN

#-> initialization

use strict;
use warnings;

use Test::More tests => 5;
use Test::Exception;
use Test::Mojo;

BEGIN {
    use_ok('Navel::Scheduler');
    use_ok('Navel::Logger');
    use_ok('Navel::Scheduler::Mojolicious::Application');
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
        main_configuration_file_path => $main_configuration_file_path
    );
} 'Navel::Scheduler->new(): loading and preparing main configuration from ' . $main_configuration_file_path;

lives_ok {
    $mojolicious_tester = Test::Mojo->new(
        Navel::Scheduler::Mojolicious::Application->new($scheduler)
    );
}

#-> END

__END__
