# Copyright 2015 Navel-IT
# navel-scheduler is developed by Yoann Le Garff, Nicolas Boquet and Yann Le Bras under GNU GPL v3

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
        'Navel::API' => 0,
        'EV' => 0,
        'AnyEvent::IO' => 0,
        'AnyEvent::AIO' => 0,
        'IO::AIO' => 0,
        'Sereal' => 0,
        'AnyEvent::Fork' => 0,
        'AnyEvent::Fork::RPC' => 0,
        'Getopt::Long::Descriptive' => 0,
        'Sys::Hostname' => 0,
        'Cwd' => 0,
        'File::ShareDir' => 0,
        'Mojolicious' => 0
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
