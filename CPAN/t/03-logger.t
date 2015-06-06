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

unlink $log_file if ok(Navel::Logger->new('notice', $log_file)->push_to_queue(__FILE__, 'notice')->flush_queue(), 'new()->push_to_queue()->flush_queue() : push datas in ' . $log_file);

#-> END

__END__
