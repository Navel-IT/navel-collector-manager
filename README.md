navel-scheduler
===============

navel-scheduler's purpose is to get back datas from collectors at scheduled time then encode and push it through a broker to navel-storer.

It is build on top of `Mojolicious`, `AnyEvent` (with `EV` (interface to `libev`) backend) and `AnyEvent::Fork::RPC` and must work on all Linux platforms.

Status
------

- master

[![Build Status](https://travis-ci.org/Navel-IT/navel-scheduler.svg?branch=master)](https://travis-ci.org/Navel-IT/navel-scheduler?branch=master)
[![Coverage Status](https://coveralls.io/repos/github/Navel-IT/navel-scheduler/badge.svg?branch=master)](https://coveralls.io/github/Navel-IT/navel-scheduler?branch=master)

- devel

[![Build Status](https://travis-ci.org/Navel-IT/navel-scheduler.svg?branch=devel)](https://travis-ci.org/Navel-IT/navel-scheduler?branch=devel)
[![Coverage Status](https://coveralls.io/repos/github/Navel-IT/navel-scheduler/badge.svg?branch=devel)](https://coveralls.io/github/Navel-IT/navel-scheduler?branch=devel)

Install
-------

Check this [repository](https://github.com/navel-it/navel-installation-scripts).

Prepare configuration
---------------------

- *main.yml* ([t/01-main.yml](t/01-main.yml)) is the entrypoint for the configuration of navel-scheduler. Most of this properties can't be changed at runtime.

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

You could use a reverse proxy (with *main.yml*:`webservices/mojo_server/reverse_proxy` set to `1` or `true`) such as *nginx* if you want to have more control resources access.

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

- Others parts of the configuration of navel-scheduler must be done via the REST API.

Start
-----

All the help is available with `navel-scheduler --help`.

- Manually

```
[root@navel-scheduler ~]# navel-scheduler /usr/local/etc/navel-scheduler/main.yml --log-no-color --log-severity=info
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

- They must always contain a subroutine named `collect`.
- The subroutine named `__collect` is reserved and therefore should never be used in a collector.
- `STDIN`, `STDOUT` and `STDERR` are closed.
- The error messages (syntax error, `die`, ...) aren't accurate. Don't test your collectors with navel-scheduler.

A collector of type *package*:

```perl
package Navel::Collectors::JIRA::Issue;

use Navel::Base;

use Navel::Event;

use JIRA::REST;

sub collect {
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
