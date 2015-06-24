# Copyright 2015 Navel-IT
# Navel Scheduler is developed by Yoann Le Garff, Nicolas Boquet and Yann Le Bras under GNU GPL v3

#-> BEGIN

#-> initialization

use strict;
use warnings;

use ExtUtils::MakeMaker 6.64;

#-> main

my $min_per_version = '5.10.1';

WriteMakefile(
    NAME => 'Navel::Scheduler',
    VERSION_FROM => 'lib/Navel/Scheduler.pm',
    ABSTRACT => 'Navel scheduler',
    AUTHOR => 'Yoann Le Garff, Nicolas Boquet and Yann Le Bras',
    LICENSE => 'GNU GPL v3',
    META_MERGE => {
        requires => {
            perl => $min_per_version
        },
        resources => {
            license => 'http://www.gnu.org/copyleft/gpl.html',
            repository => 'http://github.com/navel-it/navel-scheduler'
        },
        no_index => {
            directory => ['t']
        }
    },
    MIN_PERL_VERSION => $min_per_version,
    CONFIGURE_REQUIRES => {
       'ExtUtils::MakeMaker' => 6.64
    },
    PREREQ_PM => {
        'Scalar::Util::Numeric' => 0,
        'File::Slurp' => 0,
        'IO::AIO' => 0,
        'JSON' => 0,
        'IPC::Cmd' => 0,
        'Net::AMQP::RabbitMQ' => 0,
        'Carp' => 0,
        'EV' => 0,
        'AnyEvent::DateTime::Cron' => 0,
        'AnyEvent::AIO' => 0,
        'AnyEvent::Fork' => 0,
        'AnyEvent::Fork::RPC' => 0,
        'Exporter::Easy' => 0,
        'Storable' => 0,
        'Data::Validate::Struct' => 0,
        'Scalar::Util' => 0,
        'DateTime::Event::Cron::Quartz' => 0,
        'Getopt::Long' => 0,
        'Pod::Usage' => 0,
        'List::MoreUtils' => 0,
        'String::Util' => 0,
        'Cwd' => 0,
        'Proc::Daemon' => 0,
        'Mojolicious' => 0
    },
    TEST_REQUIRES => {
        'Test::More' => 0,
        'Test::Exception' => 0
    },
    EXE_FILES => ['bin/navel-scheduler'],
    test => {
        TESTS => 't/*.t'
    }
);

#-> END

__END__
