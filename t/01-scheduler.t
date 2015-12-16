# Copyright 2015 Navel-IT
# navel-scheduler is developed by Yoann Le Garff, Nicolas Boquet and Yann Le Bras under GNU GPL v3

#-> BEGIN

#-> initialization

use strict;
use warnings;

use Test::More tests => 4;
use Test::Exception;

BEGIN {
    use_ok('Navel::Scheduler');
    use_ok('Navel::Logger');
}

#-> main

my $main_configuration_file_path = 't/01-main.json';

my $scheduler;

lives_ok {
    $scheduler = Navel::Scheduler->new(
        main_configuration_file_path => $main_configuration_file_path
    );
} 'Navel::Scheduler::new(): loading main configuration from ' . $main_configuration_file_path;

lives_ok {
    $scheduler->prepare(
        logger => Navel::Logger->new(
            severity => 'debug'
        )
    );
} 'Navel::Scheduler::prepare(): preparing configuration';

#-> END

__END__
