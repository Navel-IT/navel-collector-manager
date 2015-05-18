# Copyright 2015 Navel-IT
# Navel Scheduler is developped by Yoann Le Garff, Nicolas Boquet and Yann Le Bras under GNU GPL v3

#-> BEGIN

#-> initialization

use strict;
use warnings;

use Test::More;

BEGIN {
    use_ok('Navel::RabbitMQ::Serialize::Data', ':all');
}

#-> main

my $return = eval {
    to(
        Navel::Definition::Connector->new(
            {
                name => 'nagios_host_and_services_1',
                collection => 'nagios_host_and_services',
                type => 'external',
                scheduling => '* * * * *',
                exec_directory_path => ''
            }
        ),
        '
        {
            "a" : 0,
            "b" : 1
        }
        '
    );
};


ok(from($return->[1])->[0], 'from() : deserialize datas') if (ok($return->[0], 'to() : serialize datas'));

done_testing();

#-> END

__END__