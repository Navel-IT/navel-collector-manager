# Copyright 2015 Navel-IT
# navel-scheduler is developed by Yoann Le Garff, Nicolas Boquet and Yann Le Bras under GNU GPL v3

#-> BEGIN

#-> initialization

use strict;
use warnings;

use Test::More tests => 3;
use Test::Exception;

BEGIN {
    use_ok('Navel::Scheduler');
    use_ok('Navel::Logger');
}

#-> main

my $main_configuration_file_path = 't/01-main.yml';

my $scheduler;

lives_ok {
    $scheduler = Navel::Scheduler->new(
        logger => Navel::Logger->new(
            facility => 'local0',
            severity => 'debug'
        ),
        main_configuration_file_path => $main_configuration_file_path
    );
} 'Navel::Scheduler->new(): loading and preparing main configuration from ' . $main_configuration_file_path;

#-> END

__END__
