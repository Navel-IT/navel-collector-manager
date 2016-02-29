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

List of the availables properties for *webservices/mojo_server* (more details [here](http://mojolicio.us/perldoc/Mojo/Server/Daemon#ATTRIBUTES)):

Property name | Property type
------------- | -------------
reverse_proxy | boolean
backlog | integer
inactivity_timeout | integer
max_clients | integer
max_requests | integer

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

API
---

- REST

The documentation is available as POD through the Swagger spec:

```bash
perl -MNavel::API::Swagger2::Scheduler -e 'print Navel::API::Swagger2::Scheduler->new()->pod()->to_string();' | pod2man | nroff -man | less
```

- WebSocket

navel-scheduler expose the following endpoints:

Endpoint | Summary
-------- | -------
/api/logger/stream | stream the output of the core logger

Collectors
----------

There are two types of collectors:

- Perl package (.pm).
- Perl source (.pl).

**Notes**:

- They must always contain a subroutine named `collector`.
- The subroutine named `__collector` is reserved and therefore should never be used in a collector.
- `STDIN`, `STDOUT` and `STDERR` are closed.
- The error messages (syntax error, `die`, ...) aren't accurate. Don't test your collectors with navel-scheduler.

A collector of type *package*:

```perl
package Navel::Collectors::JIRA::Issue;

use Navel::Base;

use Navel::Event;

use JIRA::REST;

sub collector {
    my $collector = shift;

    my ($logger_severity, $logger_message, $event);

    my $search = eval {
        JIRA::REST->new(
            $collector->{input}->{url},
            $collector->{input}->{user},
            $collector->{input}->{password},
            $collector->{input}->{rest_client}
        )->POST(
            '/search',
            undef,
            $collector->{input}->{headers}
        );
    };

    if ($@) {
        $logger_severity = 'warning';

        $logger_message = $@;

        $event = [
            Navel::Event::OK,
            $@
        ];
    } else {
        $logger_severity = 'notice';

        $logger_message = "I've found " . @{$search} . ' issues!';

        $event = [
            Navel::Event::KO,
            $search
        ];
    }

    AnyEvent::Fork::RPC::event(
        [
            $logger_severity,
            $logger_message
        ]
    ); # send a message the the logger

    $event;
}

1;
```
