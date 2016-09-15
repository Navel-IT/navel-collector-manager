navel-scheduler
===============

navel-scheduler's purpose is to get back data from collectors at scheduled time then encode and push it through a broker to navel-storer.

Status
------

- master

[![Build Status](https://travis-ci.org/Navel-IT/navel-scheduler.svg?branch=master)](https://travis-ci.org/Navel-IT/navel-scheduler?branch=master)
[![Coverage Status](https://coveralls.io/repos/github/Navel-IT/navel-scheduler/badge.svg?branch=master)](https://coveralls.io/github/Navel-IT/navel-scheduler?branch=master)

- devel

[![Build Status](https://travis-ci.org/Navel-IT/navel-scheduler.svg?branch=devel)](https://travis-ci.org/Navel-IT/navel-scheduler?branch=devel)
[![Coverage Status](https://coveralls.io/repos/github/Navel-IT/navel-scheduler/badge.svg?branch=devel)](https://coveralls.io/github/Navel-IT/navel-scheduler?branch=devel)

Installation
------------

Check this [repository](https://github.com/navel-it/navel-installation-scripts).

Usage
-----

All the help is available with `navel-scheduler --help`.

- Manually

```
[root@vmbox tmp]# navel-scheduler /usr/local/etc/navel-scheduler/meta.yml
June 14 18:52:04 vmbox navel-scheduler[5211] 133 initialization done.
June 14 18:52:04 vmbox navel-scheduler[5211] 133 Navel::Definition::Publisher.Navel::Broker::Client::Fork::Publisher::Backend::RabbitMQ.版元-rabbitmq-1: initialization.
June 14 18:52:07 vmbox navel-scheduler[5211] 133 Navel::Definition::Publisher.Navel::Broker::Client::Fork::Publisher::Backend::RabbitMQ.版元-rabbitmq-1: connecting.
June 14 18:52:09 vmbox navel-scheduler[5211] 133 Navel::Definition::Publisher.Navel::Broker::Client::Fork::Publisher::Backend::RabbitMQ.版元-rabbitmq-1: successfully connected.
June 14 18:52:09 vmbox navel-scheduler[5211] 133 Navel::Definition::Publisher.Navel::Broker::Client::Fork::Publisher::Backend::RabbitMQ.版元-rabbitmq-1: channel opened.
```

- As a service

By default, the service is named *navel-scheduler* and run under the user and the group of the same name.

If you want to change the service options, edit */etc/sysconfig/navel-scheduler* or */etc/default/navel-scheduler* in accordance with the help.

API
---

- REST

The documentation is available through the Swagger spec:

```bash
mojo swagger2 edit $(perl -MNavel::API::Swagger2::Scheduler -e 'print Navel::API::Swagger2::Scheduler->spec_file_location();') --listen http://*:8080
```

- WebSocket

navel-scheduler expose the following endpoints:

Endpoint | Summary
-------- | -------
/api/logger/stream | stream the output of the core logger

Collectors
----------

- They are meant to retrieve events.
- They can be a synchronous task (`sync` set to `0` or `false`) or a more complex server using an event loop and generating events on external "calls" (`sync` set to `1` or `true`).
 - Documentation can be found [here](https://metacpan.org/pod/AnyEvent::Fork::RPC).
- They are Perl packages.
- A subroutine named `collect` must be declared.
- Subroutines `enable` and `disable` must be declared if the collector is asynchronous.
- The data returned by this subroutine are not used by the master process, instead there are two methods to do this:
 - `Navel::Scheduler::Core::Collector::Fork::Worker::event($data, $data, ...)` which send event(s) to the publishers.
 - `Navel::Scheduler::Core::Collector::Fork::Worker::log([$severity, $text], [$severity, $text], ...)` which send message(s) to the logger.
- `STDIN`, `STDOUT` and `STDERR` are redirected to `/dev/null`.

[Example of an asynchronous collector](https://github.com/Navel-IT/navel-collector-monitoring-plugin).

Copyright
---------

Copyright (C) 2015-2016 Yoann Le Garff, Nicolas Boquet and Yann Le Bras

License
-------

navel-scheduler is licensed under the Apache License, Version 2.0
