navel-scheduler
===============

[![Build Status](https://travis-ci.org/Navel-IT/navel-scheduler.svg)](https://travis-ci.org/Navel-IT/navel-scheduler)

navel-scheduler's purpose is to get back datas from collectors at scheduled time then encode and push it through RabbbitMQ to navel-storer.

It is build on top of `Mojolicious` + `AnyEvent` and must work on all Linux platforms.

Install
-------

Check this [repository](https://github.com/navel-it/navel-installation-scripts).

Prepare configuration
---------------------

*main.json* is the entrypoint for the configuration of navel-scheduler. Most of this properties cannot be changed at runtime. It must look like this:

```javascript
{
    "collectors": {
        "definitions_from_file": "/usr/local/etc/navel-scheduler/collectors.json",
        "collectors_exec_directory": "/usr/local/etc/navel-scheduler/collectors",
        "maximum": 0,
        "maximum_simultaneous_exec": 0,
        "execution_timeout": 0
    },
    "rabbitmq": {
        "definitions_from_file": "/usr/local/etc/navel-scheduler/rabbitmq.json",
        "maximum": 0,
        "maximum_simultaneous_exec": 0
    },
    "webservices": {
        "definitions_from_file": "/usr/local/etc/navel-scheduler/webservices.json",
        "credentials": { // changeable at runtime
            "login": "admin",
            "password": "password"
        },
        "mojo_server": {
        }
    }
}
```

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

*webservices.json* contains the definitions of navel-scheduler's web services and cannot be changed at runtime. It must look like this:

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

Others parts of the configuration of navel-scheduler must be done via the REST API.

For RabbitMQ installation and configuration, see [here](http://www.rabbitmq.com/documentation.html).

Service
-------

By default, the service will run under *navel-scheduler:navel-scheduler*.

If you want to change the service options, edit */etc/sysconfig/navel-scheduler* in accordance with the options returned by `navel-scheduler --help`.

- systemd

`systemctl <action> navel-scheduler`

- SysV

`service navel-scheduler <action>`


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

- They must always contain a function named `collector`.
- `STDOUT` and `STDERR` are closed.
- The `__collector` function is reserved.
- The error messages (syntax error, `die`, ...) are not accurate. First test your collectors manually.

An exemple of Perl package collector:

```perl
package Navel::Collectors::Exemple;

use strict;
use warnings;

sub collector {
    my ($collector_properties, $input) = @_;

    my @datas; # or retrieve datas from databases, message brokers, web services, ....

    AnyEvent::Fork::RPC::event("It's done father!") # send a log message to navel-scheduler

    \@datas;
}

1;
```

An exemple of Perl source collector:

```perl
use strict;
use warnings;

sub collector {
    my ($collector_properties, $input) = @_;

    my @datas; # or retrieve datas from databases, message brokers, web services, ....

    AnyEvent::Fork::RPC::event("It's done father!") # send a log message to navel-scheduler

    \@datas;
}
```
