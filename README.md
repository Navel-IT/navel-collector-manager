navel-scheduler
===============

**WORK-IN-PROGRESS**

navel-scheduler's purpose is to get back datas from connectors at scheduled (Quartz expressions) time then encode and push it through RabbbitMQ to navel-router.

**Must work on all Linux (perhaps Unix) platforms but only tested on RHEL/CentOS 6.x.**

Build it
--------

CPAN : `build_cpan_archive.sh <version>`

RPM : `build_rpm_archive.sh <version> <release>`

Install it
----------

CPAN : `cpanm <cpan-archive>.tar.gz -n`

RPM : `yum localinstall <rpm-archive>.rpm`

Use it
------

`service navel-scheduler <action>`

REST API
--------

The following routes are currently availables :

```
/scheduler/api    GET
/scheduler/api/general(?action=/^write_configuration$/)    GET
/scheduler/api/general/webservices    PUT
/scheduler/api/cron/jobs    GET
/scheduler/api/connectors    GET, POST
/scheduler/api/connectors/(:connector)    GET, PUT, DEL
/scheduler/api/rabbitmq    GET, POST
/scheduler/api/rabbitmq/(:rabbitmq)    GET, PUT, DEL
/scheduler/api/publishers    GET
/scheduler/api/publishers/(:publisher)(?action=/^(clear_queue|connect|disconnect)$/)    GET
/scheduler/api/webservices    GET
/scheduler/api/webservices/(:webservice)    GET
```