# Copyright 2015 Navel-IT
# navel-scheduler is developed by Yoann Le Garff, Nicolas Boquet and Yann Le Bras under GNU GPL v3

#-> BEGIN

#-> initialization

use strict;
use warnings;

use ExtUtils::MakeMaker 6.64;

#-> main

my $min_perl_version = '5.10.1';

WriteMakefile(
    NAME => 'Navel::Scheduler',
    VERSION_FROM => 'lib/Navel/Scheduler.pm',
    ABSTRACT => 'navel-scheduler',
    AUTHOR => 'Yoann Le Garff, Nicolas Boquet and Yann Le Bras',
    LICENSE => 'GNU GPL v3',
    META_MERGE => {
        requires => {
            perl => $min_perl_version
        },
        resources => {
            license => 'http://www.gnu.org/copyleft/gpl.html',
            repository => 'http://github.com/Navel-IT/navel-scheduler'
        },
        no_index => {
            directory => ['t']
        }
    },
    MIN_PERL_VERSION => $min_perl_version,
    PREREQ_PM => {
        'Navel::Base' => 0,
        'Exporter::Easy' => 0,
        'Carp' => 0,
        'EV' => 0,
        'AnyEvent::DateTime::Cron' => 0,
        'AnyEvent::IO' => 0,
        'AnyEvent::AIO' => 0,
        'IO::AIO' => 0,
        'Sereal' => 0,
        'AnyEvent::Fork' => 0,
        'AnyEvent::Fork::RPC' => 0,
        'Getopt::Long' => 0,
        'Pod::Usage' => 0,
        'Proc::Daemon' => 0,
        'Cwd' => 0,
        'Mojolicious::Lite' => 0
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
