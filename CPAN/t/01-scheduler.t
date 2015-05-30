# Copyright 2015 Navel-IT
# Navel Scheduler is developped by Yoann Le Garff, Nicolas Boquet and Yann Le Bras under GNU GPL v3

#-> BEGIN

#-> initialization

use strict;
use warnings;

use Test::More tests => 2;

BEGIN {
    use_ok('Navel::Scheduler');
}

#-> main

my $general_configuration_file = 't/01-general.json';

my $scheduler = eval {
    Navel::Scheduler->new($general_configuration_file);
};

ok( ! $@, 'new() : loading general configuration from ' . $general_configuration_file);

#-> END

__END__
