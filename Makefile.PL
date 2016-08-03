# Copyright (C) 2015 Yoann Le Garff, Nicolas Boquet and Yann Le Bras
# navel-scheduler is licensed under the Apache License, Version 2.0

#-> BEGIN

#-> initialization

use strict;
use warnings;

use ExtUtils::MakeMaker 6.64;

use File::ShareDir::Install;

#-> main

my $min_perl_version = '5.18.0';

install_share('share');

WriteMakefile(
    NAME => 'Navel::Scheduler',
    VERSION_FROM => 'lib/Navel/Scheduler.pm',
    ABSTRACT => 'navel-scheduler',
    AUTHOR => 'Yoann Le Garff, Nicolas Boquet and Yann Le Bras',
    LICENSE => 'Apache License, Version 2.0',
    META_MERGE => {
        requires => {
            perl => $min_perl_version
        },
        resources => {
            license => 'http://www.apache.org/licenses/LICENSE-2.0.html',
            repository => 'http://github.com/Navel-IT/navel-scheduler'
        },
        no_index => {
            directory => ['t']
        }
    },
    MIN_PERL_VERSION => $min_perl_version,
    PREREQ_PM => {
        'Navel::Base' => 0,
        'Navel::Base::Daemon' => 0,
        'Navel::AnyEvent::Fork::RPC::Serializer::Sereal' => 0,
        'Navel::Mojolicious::Plugin::JSON::XS' => 0,
        'Navel::Mojolicious::Plugin::Logger' => 0,
        'Navel::Mojolicious::Plugin::Swagger2::StdResponses' => 0,
        'Navel::Logger' => 0,
        'Navel::API' => 0,
        'Navel::Event' => 0,
        'Navel::AnyEvent::Pool' => 0,
        'Navel::Broker::Client::Fork' => 0,
        'EV' => 0,
        'AnyEvent' => 0,
        'AnyEvent::Fork' => 0,
        'AnyEvent::Fork::RPC' => 0,
        'File::ShareDir' => 0,
        'Mojolicious' => 0,
        'IO::Socket::SSL' => 1.84
    },
    TEST_REQUIRES => {
        'Test::More' => 0,
        'Test::Exception' => 0
    },
    EXE_FILES => [
        'bin/navel-scheduler'
    ],
    test => {
        TESTS => 't/*.t'
    }
);

package MY;

use File::ShareDir::Install 'postamble';

#-> END

__END__
