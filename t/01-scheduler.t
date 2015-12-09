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

my $general_configuration_file = 't/01-general.json';

my $scheduler;

lives_ok {
    $scheduler = Navel::Scheduler->new(
        general_configuration_path => $general_configuration_file
    );
} 'Navel::Scheduler::new(): loading general configuration from ' . $general_configuration_file;

lives_ok {
    $scheduler->prepare(
        logger => Navel::Logger->new(
            severity => 'debug'
        )
    );
} 'Navel::Scheduler::prepare(): preparing configuration';

#-> END

__END__
