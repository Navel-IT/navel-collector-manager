# Copyright 2015 Navel-IT
# navel-scheduler is developed by Yoann Le Garff, Nicolas Boquet and Yann Le Bras under GNU GPL v3

#-> BEGIN

#-> initialization

use strict;
use warnings;

use Test::More tests => 2;
use Test::Exception;

BEGIN {
    use_ok('Navel::Scheduler');
}

#-> main

my $general_configuration_file = 't/01-general.json';

lives_ok {
    Navel::Scheduler->new(
        general_configuration_path => $general_configuration_file
    );
} 'new(): loading general configuration from ' . $general_configuration_file;

#-> END

__END__
