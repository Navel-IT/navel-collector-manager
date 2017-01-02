navel-scheduler
===============

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

```
[root@vmbox tmp]# navel-scheduler /usr/local/etc/navel-scheduler/meta.json
Oct 18 18:52:04 vmbox navel-scheduler[5211] 133 initialization done.
Oct 18 18:52:04 vmbox navel-scheduler[5211] 133 Navel::Definition::Collector.Navel::Collector::Monitoring::Plugin.nagios-worker-1: initialization.
```

All the help is available via `navel-scheduler --help`.

API
---

- REST

The documentation is available through the OpenAPI spec.

- WebSocket

Endpoint | Summary
-------- | -------
/api/logger/stream | stream the output of the core logger

Copyright
---------

Copyright (C) 2015-2017 Yoann Le Garff, Nicolas Boquet and Yann Le Bras

License
-------

navel-scheduler is licensed under the Apache License, Version 2.0
