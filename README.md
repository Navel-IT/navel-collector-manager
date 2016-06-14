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

Configuration
-------------

- *meta.yml* ([t/01-meta.yml](t/01-meta.yml)) is the entrypoint for the configuration of navel-scheduler.

List of the availables properties for *webservices/mojo_server* (more details [here](http://mojolicio.us/perldoc/Mojo/Server/Daemon#ATTRIBUTES)):

Property name | Property type
------------- | -------------
reverse_proxy | boolean
backlog | integer
inactivity_timeout | integer
max_clients | integer
max_requests | integer

- *webservices.yml* contains the definitions of navel-scheduler's web services and can't be changed at runtime. It must look like this:

```yaml
---
  -
    name: direct
    interface_mask: '*'
    port: 8443
    tls: 1
    ca: ~
    cert: '/usr/local/etc/navel-scheduler/ssl/navel-scheduler.crt'
    ciphers: ~
    key: '/usr/local/etc/navel-scheduler/ssl/navel-scheduler.key'
    verify: ~
  -
    name: behind-nginx
    interface_mask: '127.0.0.1'
    port: 8080
    tls: 0
    ca: ~
    cert: ~
    ciphers: ~
    key: ~
    verify: ~
```

The web services offers only a single "administrator level" user authentication mechanism.

You could use a reverse proxy (with *meta.yml*:`webservices/mojo_server/reverse_proxy` set to `1` or `true`) such as *nginx* if you want to have more control over access to resources.

For example, a read-only access:

```nginx
upstream navel-scheduler {
    server 127.0.0.1:8080;
}

server {
    listen 9443;

    ssl on;
    ssl_certificate /usr/local/etc/navel-scheduler/ssl/navel-scheduler.crt;
    ssl_certificate_key /usr/local/etc/navel-scheduler/ssl/navel-scheduler.key;

    access_log /var/log/nginx/access_navel-scheduler.log;
    error_log /var/log/nginx/error_navel-scheduler.log;

    proxy_redirect off;

    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header Authorization 'Basic YWRtaW46cGFzc3dvcmQ='; # "admin:password" base64 encoded

    location / {
        auth_basic 'read-only';
        auth_basic_user_file '/etc/nginx/htpasswd/navel-scheduler/read-only.htpasswd';

        if ($request_method != 'GET') {
            return 403;
        }

        proxy_pass http://navel-scheduler;
    }
}
```

- Others parts of the configuration of navel-scheduler must be done over REST.

Usage
-----

All the help is available with `navel-scheduler --help`.

- Manually

```
[root@vmbox tmp]# navel-scheduler /usr/local/etc/navel-scheduler/meta.yml
June 14 18:52:04 vmbox navel-scheduler[5211] 133 initialization done.
June 14 18:52:04 vmbox navel-scheduler[5211] 133 starting the webservices.
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
- The data returned by this subroutine are not used by the master process, instead there are two methods to do this:
 - `Navel::Scheduler::Core::Collector::Fork::Worker::event($data, $data, ...)` which send event(s) to the publishers.
 - `Navel::Scheduler::Core::Collector::Fork::Worker::log([$severity, $text], [$severity, $text], ...)` which send message(s) to the logger.
- `STDIN`, `STDOUT` and `STDERR` are redirected to `/dev/null`.

[Example of an asynchronous collector](https://github.com/Navel-IT/navel-collector-monitoring-plugin).

Copyright
---------

Copyright (C) 2015 Yoann Le Garff, Nicolas Boquet and Yann Le Bras

License
-------

navel-scheduler is licensed under the Apache License, Version 2.0
