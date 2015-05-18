# Copyright 2015 Navel-IT
# Navel Scheduler is developped by Yoann Le Garff, Nicolas Boquet and Yann Le Bras under GNU GPL v3

#-> BEGIN

#-> initialization

use strict;
use warnings;

use Test::More tests => 2;

BEGIN {
    use_ok('Navel::Logger');
}

#-> main

my $log_file = '/logger.log';

unlink $log_file if ok(Navel::Logger->new($log_file)->push_to_buffer(__FILE__)->flush_buffer(), 'new()->push_to_buffer()->flush_buffer() : push datas in ' . $log_file);

#-> END

__END__