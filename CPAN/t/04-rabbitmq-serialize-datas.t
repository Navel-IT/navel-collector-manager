# Copyright 2015 Navel-IT
# Navel Scheduler is developed by Yoann Le Garff, Nicolas Boquet and Yann Le Bras under GNU GPL v3

#-> BEGIN

#-> initialization

use strict;
use warnings;

use Test::More;
use Test::Exception;

BEGIN {
    use_ok('Navel::RabbitMQ::Serialize::Data', ':all');
}

#-> main

my $serialized;

if (lives_ok {
    $serialized = to(
        {
            a => 0,
            b => 1
        },
        Navel::Definition::Connector->new(
            {
                name => 'test-1',
                collection => 'test',
                type => 'code',
                singleton => 1,
                scheduling => '0 * * * * ?',
                source => undef,
                input => undef,
                exec_directory_path => ''
            }
        ),
        'test'
    );
} 'to() : serialize') {
    lives_ok {
        from($serialized);
    } 'from() : deserialize';
}

done_testing();

#-> END

__END__
