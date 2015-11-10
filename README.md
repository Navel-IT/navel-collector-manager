navel-scheduler
===============

[![Build Status](https://travis-ci.org/Navel-IT/navel-scheduler.svg)](https://travis-ci.org/Navel-IT/navel-scheduler)

navel-scheduler's purpose is to get back datas from collectors at scheduled (Quartz expressions) time then encode and push it through RabbbitMQ to navel-storer.

It is build on top of `Mojolicious::Lite` + `AnyEvent` and must work on all Linux platforms.

Install
-------

Check this [repository](https://github.com/navel-it/navel-installation-scripts).

Prepare configuration
---------------------

*general.json* is the entrypoint for the configuration of navel-scheduler. Most of this properties cannot be changed at runtime. It must look like this:

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
        "maximum": 0
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

The following endpoints are currently availables for informations and runtime modifications.

**Note**: JSON below URI are exemples of what HTTP message body you should get (**GET**, **DEL**) or send (**POST**, **PUT**).

- **GET** - read
  - /scheduler/api
```json
{
    "version": 0.1
}
```
  - /scheduler/api/general
```json
{
    "collectors": {
        "definitions_from_file": "/usr/local/etc/navel-scheduler/collectors.json",
        "collectors_exec_directory": "/usr/local/etc/navel-scheduler/collectors",
        "maximum": 0,
        "maximum_simultaneous_exec": 0,
        "execution_timeout": 0
    },
    "rabbitmq": {
        "definitions_from_file": "/usr/local/etc/navel-scheduler/rabbitmq.json"
    },
    "webservices": {
        "definitions_from_file": "/usr/local/etc/navel-scheduler/webservices.json",
        "credentials": {
            "login": "admin",
            "password": "password"
        },
        "mojo_server": {
        }
    }
}
```
  - /scheduler/api/jobs
```json
{
    "types": [
        "collector",
        "publisher",
        "logger"
    ]
}
```
  - /scheduler/api/jobs/(:job_type)
```json
[
    "glpi-1"
]
```
  - /scheduler/api/jobs/(:job_type)/(:job_name)
```json
{
    "enabled": 1
}
```
  - /scheduler/api/collectors
```json
[
    "nagios-1",
    "glpi-1"
]
```
  - /scheduler/api/collectors/(:collector)
```json
{
    "name": "nagios-1",
    "collection": "nagios",
    "type": "package",
    "singleton": 1,
    "scheduling": "15 * * * * ?",
    "source": "Navel::Collector::Nagios",
    "input": {
        "url": "http://login:password@my.home.com"
    }
}
```
  - /scheduler/api/rabbitmq
```json
[
    "rabbitmq-1",
    "rabbitmq-2"
]
```
  - /scheduler/api/rabbitmq/(:rabbitmq)
```json
{
    "name": "rabbitmq-1",
    "host": "172.16.1.1",
    "port": 5672,
    "user": "guest",
    "password": "guest",
    "timeout": 0,
    "vhost": "/",
    "tls": 0,
    "heartbeat": 30,
    "exchange": "amq.topic",
    "delivery_mode": 2,
    "scheduling": "*/15 * * * * ?",
    "auto_connect": 1
}
```
  - /scheduler/api/publishers
```json
[
    "rabbitmq-1",
    "rabbitmq-2"
]
```
  - /scheduler/api/publishers/(:publisher)
```json
{
    "name": "rabbitmq-1",
    "connected": 0,
    "messages_in_queue": 500
}
```
  - /scheduler/api/publishers/(:publisher)/events
```json
[
    "*/1 * * * * ?einput(*gsecondsdnamegsleep-1/esleepsexec_directory_path&)/usr/local/etc/n"
]
```
  - /scheduler/api/webservices
```json
[
    "webservice-1",
    "webservice-2"
]
```
  - /scheduler/api/webservices/(:webservice)
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
    }
]
```
- **POST** - create
  - /scheduler/api/collectors
```json
{
    "name": "glpi-2",
    "collection": "glpi",
    "type": "file_code",
    "singleton": 1,
    "scheduling": "15 * * * * ?",
    "source": "glpi",
    "input": {
        "url": "http://login:password@my.home.com:8080"
    }
}
```
  - /scheduler/api/rabbitmq
```json
{
    "name": "rabbitmq-3",
    "host": "172.16.1.3",
    "port": 5672,
    "user": "guest",
    "password": "guest",
    "timeout": 0,
    "vhost": "/",
    "tls": 0,
    "heartbeat": 30,
    "exchange": "amq.topic",
    "delivery_mode": 2,
    "scheduling": "*/15 * * * * ?",
    "auto_connect": 1
}
```
  - /scheduler/api/publishers/(:publisher)/events
```javascript
{
    "event_definition": {
        "datas": [
            "foo",
            "bar"
        ],
        "collection": "my-app",
        "starting_time" : 1440959939, // default value : current POSIX timestamp
        "ending_time" : 1440959951 // default value : current POSIX timestamp
    },
    "status": "ko_exception" // "ok", "ko_no_source" and "ko_exception" are available. Default value : "ok"
}
```
- **PUT** - modify
  - /scheduler/api/save_configuration
```json
{}
```
  - /scheduler/api/general/webservices/credentials
```json
{
    "password": "new_password"
}
```
  - /scheduler/api/jobs/(:job_type)/(:job_name)/enable
```json
{}
```
  - /scheduler/api/jobs/(:job_type)/(:job_name)/disable
```json
{}
```
  - /scheduler/api/collectors/(:collector)
```json
{
    "scheduling": "*/30 * * * * ?"
}
```
  - /scheduler/api/rabbitmq/(:rabbitmq)
```json
{
    "timeout": 5
}
```
  - /scheduler/api/publishers/(:publisher)/connect
```json
{}
```
  - /scheduler/api/publishers/(:publisher)/disconnect
```json
{}
```
- **DELETE** - delete
  - /scheduler/api/collectors/(:collector)
```json
{
    "ok": [
        "Collector glpi-2 unregistered and deleted"
    ],
    "ko": []
}
```
  - /scheduler/api/rabbitmq/(:rabbitmq)
```json
{
    "ok": [
        "Publisher rabbitmq-3 disconnected, unregistered and deleted",
        "RabbitMQ rabbitmq-3 deleted"
    ],
    "ko": []
}
```
  - /scheduler/api/publishers/(:publisher)/events
```json
{}
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
