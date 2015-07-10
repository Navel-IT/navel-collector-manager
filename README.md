navel-scheduler
===============

navel-scheduler's purpose is to get back datas from connectors at scheduled (Quartz expressions) time then encode and push it through RabbbitMQ to navel-router.

**Must work on all Linux platforms but only tested on RHEL/CentOS 6.x.**

Build
-----

- CPAN : `build_cpan_archive.sh <version>`

- RPM : `build_rpm_archive.sh <version> <release>`

Install
-------

- CPAN : `cpanm <cpan-archive> -n`

- RPM : `yum localinstall <rpm-archive>`

Prepare configuration
---------------------

*general.json* is the entrypoint for the configuration of navel-scheduler. Most of this properties cannot be changed at runtime. It must look like this :

```javascript
{
    "definitions_path" : {
        "connectors" : "/etc/navel-scheduler/connectors.json",
        "connectors_exec_directory" : "/etc/navel-scheduler/connectors", // this directory contains the connectors (scripts)
        "rabbitmq" : "/etc/navel-scheduler/rabbitmq.json",
        "webservices" : "/etc/navel-scheduler/webservices.json"
    },
    "webservices" : { // properties shared by all the web services
        "login" : "admin", // can be changed at runtime
        "password" : "password", // can be changed at runtime
        "mojo_server" : { // Mojo::Server::Prefork properties
        }
    },
    "rabbitmq" : { // properties shared by all the rabbitmq clients
        "auto_connect" : 1 // 0 or 1. Automatically connect navel-scheduler to rabbitmq servers when a rabbitmq definition is added or when navel-scheduler start
    }
}
```

*webservices.json* contains the definitions of navel-scheduler's web services and cannot be changed at runtime. It must look like this :

```javascript
[
    {
        "name" : "webservice-1", // web service (unique name)
        "interface_mask" : "*", // this web service will be listening on this mask
        "port" : 3000, // this web service will be listening on this port
        "tls" : 0 // 0 or 1. Enable TLS
    },
    {
        "name" : "webservice-2",
        "interface_mask" : "*",
        "port" : 3000,
        "tls" : 0
    }
]
```

Others parts of the configuration must be done via the REST API.

Service
-------

`service navel-scheduler <action>`

REST API
--------

The following endpoints are currently availables for informations and runtime modifications.

- **GET**
  - /scheduler/api
  - /scheduler/api/general(?action=/^write_configuration$/)
  - /scheduler/api/cron/jobs
  - /scheduler/api/connectors
  - /scheduler/api/connectors/(:connector)
  - /scheduler/api/rabbitmq
  - /scheduler/api/rabbitmq/(:rabbitmq)
  - /scheduler/api/publishers
  - /scheduler/api/publishers/(:publisher)(?action=/^(clear_queue|connect|disconnect)$/)
  - /scheduler/api/webservices
  - /scheduler/api/webservices/(:webservice)
- **POST**
  - /scheduler/api/connectors
  - /scheduler/api/rabbitmq
- **PUT**
  - /scheduler/api/general/webservices
  - /scheduler/api/connectors/(:connector)
  - /scheduler/api/rabbitmq/(:rabbitmq)
  - /scheduler/api/publishers/(:publisher)
- **DEL**
  - /scheduler/api/connectors
  - /scheduler/api/rabbitmq
