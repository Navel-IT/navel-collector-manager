navel-scheduler
===============

[![Build Status](https://travis-ci.org/Navel-IT/navel-scheduler.svg)](https://travis-ci.org/Navel-IT/navel-scheduler)

navel-scheduler's purpose is to get back datas from collectors at scheduled time then encode and push it through a broker to navel-storer.

It is build on top of `Mojolicious` + `AnyEvent` and must work on all Linux platforms.

Install
-------

Check this [repository](https://github.com/navel-it/navel-installation-scripts).

Prepare configuration
---------------------

- *main.json* ([t/01-main.json](t/01-main.json)) is the entrypoint for the configuration of navel-scheduler. Most of this properties can't be changed at runtime.

List of the availables properties for *webservices/mojo_server* (more details [here](http://mojolicio.us/perldoc/Mojo/Server/Prefork#ATTRIBUTES)):

Property name  | Property type
------------- | -------------
reverse_proxy | int
backlog | int
inactivity_timeout | int
max_clients | int
max_requests | int
accepts | int
accept_interval | float
graceful_timeout | float
heartbeat_interval | float
heartbeat_timeout | float
multi_accept | int
workers | int

- *webservices.json* contains the definitions of navel-scheduler's web services and can't be changed at runtime. It must look like this:

```json
[
    {
        "name": "webservice-1",
        "interface_mask": "*",
        "port": 22080,
        "tls": 0,
        "ca": null,
        "cert": null,
        "ciphers": null,
        "key": null,
        "verify": null
    },
    {
        "name": "webservice-2",
        "interface_mask": "*",
        "port": 22443,
        "tls": 1,
        "ca": null,
        "cert": null,
        "ciphers": null,
        "key": null,
        "verify": null
    }
]
```

- Others parts of the configuration of navel-scheduler must be done via the REST API.

Start
-----

All the help is available with `navel-scheduler --help`.

- Manually

```
[root@navel-scheduler ~]# navel-scheduler /usr/local/etc/navel-scheduler/main.json --log-no-color --log-severity=info
2016-01-16 17-00-51 +0000 navel-scheduler[2724] (notice): initialization.
2016-01-16 17-00-51 +0000 navel-scheduler[2724] (notice): starting the webservices.
2016-01-16 17-00-51 +0000 navel-scheduler[2724] (notice): webservices started.
2016-01-16 17-00-51 +0000 navel-scheduler[2724] (info): spawned a new process for collector dummy-0.
2016-01-16 17-00-51 +0000 navel-scheduler[2724] (info): spawned a new process for collector dummy-1.
2016-01-16 17-00-53 +0000 navel-scheduler[2724] (warning): job dummy-1 is already running.
2016-01-16 17-00-54 +0000 navel-scheduler[2724] (warning): job dummy-0 is already running.
2016-01-16 17-00-55 +0000 navel-scheduler[2724] (warning): job dummy-1 is already running.
```

- As a service

By default, the service is named *navel-scheduler* and run under the user and the group of the same name.

If you want to change the service options, edit */etc/sysconfig/navel-scheduler* or */etc/default/navel-scheduler* in accordance with the help.

REST API
--------

The documentation is available as POD through the Swagger spec:

```bash
perl -MNavel::API::Swagger2::Scheduler -e 'print Navel::API::Swagger2::Scheduler->new()->pod()->to_string();' | pod2man | nroff -man | less
```

Collectors
----------

There are two types of collectors:

- Perl package.
- Perl source.

**Notes for Perl based collectors**:

- They must always contain a subroutine named `collector`.
- The subroutine named `__collector` is reserved and therefore should never be used in a collector.
- `STDOUT` and `STDERR` are closed.
- The error messages (syntax error, `die`, ...) aren't accurate. Don't test your collectors with navel-scheduler.

An exemple of Perl package collector:

```perl
package Navel::Collectors::Exemple;

use Navel::Base;

sub collector {
    my $collector = shift;

    my @datas; # or retrieve datas from databases, message brokers, web services, ....

    AnyEvent::Fork::RPC::event("It's done father!") # send a log message to navel-scheduler

    \@datas;
}

1;
```

An exemple of Perl source collector:

```perl
use Navel::Base;

sub collector {
    my $collector = shift;

    my @datas; # or retrieve datas from databases, message brokers, web services, ....

    AnyEvent::Fork::RPC::event("It's done father!") # send a log message to navel-scheduler

    \@datas;
}
```
