navel-scheduler
===============

navel-scheduler's purpose is to get back datas from connectors at scheduled (Quartz expressions) time then encode and push it through RabbbitMQ to navel-router.

It is build on top of Mojolicious + AnyEvent and must work on all Linux platforms but, **at this time, it is only tested on RHEL/CentOS 6.6**.

Build and install
-----------------

Assuming you start the installation from scratch ...

**WARNING** : if the system language is not English, you may encounter some unexpected bugs while running navel-scheduler.

- **CPAN**

```shell
yum install -y git gcc bash perl libxml2 libxml2-devel
curl -L http://cpanmin.us | perl - App::cpanminus

git clone git://github.com/Navel-IT/navel-scheduler.git

cd navel-scheduler/

bash build_cpan_archive.sh '<VERSION>'
cpanm ExtUtils::MakeMaker '<CPAN-ARCHIVE>'

getent group navel-scheduler || groupadd -r navel-scheduler
getent passwd navel-scheduler || useradd -rmd /usr/local/etc/navel-scheduler/ -g navel-scheduler -s /sbin/nologin navel-scheduler

cp RPM/SOURCES/usr/local/etc/navel-scheduler/* /usr/local/etc/navel-scheduler

mkdir /var/run/navel-scheduler/ /var/log/navel-scheduler/

cp RPM/SOURCES/etc/sysconfig/navel-scheduler /etc/sysconfig/
chmod +x RPM/SOURCES/etc/init.d/navel-scheduler
cp -p RPM/SOURCES/etc/init.d/navel-scheduler /etc/init.d/

chkconfig navel-scheduler on

chown -R navel-scheduler:navel-scheduler /usr/local/bin/navel-scheduler /usr/local/etc/navel-scheduler/ /var/run/navel-scheduler/ /var/log/navel-scheduler/
```

- **RPM**

```shell
yum install -y git rpm-build gcc bash
git clone git://github.com/Navel-IT/navel-scheduler.git

cd navel-scheduler/

bash build_rpm_archive.sh '<VERSION>' '<RELEASE>'
yum localinstall '<RPM-ARCHIVE>'
```

Prepare configuration
---------------------

*general.json* is the entrypoint for the configuration of navel-scheduler. Most of this properties cannot be changed at runtime. It must look like this :

```javascript
{
    "connectors" : {
        "definitions_from_file" : "/usr/local/etc/navel-scheduler/connectors.json",
        "connectors_exec_directory" : "/usr/local/etc/navel-scheduler/connectors",
        "maximum_simultaneous_exec" : 0
    },
    "rabbitmq" : {
        "definitions_from_file" : "/usr/local/etc/navel-scheduler/rabbitmq.json"
    },
    "webservices" : {
        "definitions_from_file" : "/usr/local/etc/navel-scheduler/webservices.json",
        "credentials" : { // changeable at runtime
            "login" : "admin",
            "password" : "password"
        },
        "mojo_server" : {
        }
    }
}
```

List of the availables properties for *webservices/mojo_server* (more details [here](http://mojolicio.us/perldoc/Mojo/Server/Prefork#ATTRIBUTES)) :

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

*webservices.json* contains the definitions of navel-scheduler's web services and cannot be changed at runtime. It must look like this :

```javascript
[
    {
        "name" : "webservice-1",
        "interface_mask" : "*",
        "port" : 22080,
        "tls" : 0,
        "ca" : null,
        "cert" : null,
        "ciphers" : null,
        "key" : null,
        "verify" : null
    },
    {
        "name" : "webservice-2",
        "interface_mask" : "*",
        "port" : 22443,
        "tls" : 1,
        "ca" : null,
        "cert" : null,
        "ciphers" : null,
        "key" : null,
        "verify" : null
    }
]
```

Others parts of the configuration of navel-scheduler must be done via the REST API.

For RabbitMQ installation and configuration, see [here](http://www.rabbitmq.com/documentation.html).

Service
-------

`service navel-scheduler <action>`

If you want to change the service options, edit */etc/sysconfig/navel-scheduler* in accordance with the options returned by `navel-scheduler --help`.

**Note** : the service will run under *navel-scheduler:navel-scheduler*.

REST API
--------

The following endpoints are currently availables for informations and runtime modifications.

**Note** : JSON below URI are exemples of what HTTP message body you should get (**GET**, **DEL**) or send (**POST**, **PUT**).

- **GET** - read
  - /scheduler/api
```json
{
    "version" : 0.1
}
```
  - /scheduler/api?action=save_configuration
```json
{
    "ok" : [
        "Runtime configuration saved"
    ],
    "ko" : []
}
```
  - /scheduler/api/general
```json
{
    "connectors" : {
        "definitions_from_file" : "/usr/local/etc/navel-scheduler/connectors.json",
        "connectors_exec_directory" : "/usr/local/etc/navel-scheduler/connectors",
        "maximum_simultaneous_exec" : 0
    },
    "rabbitmq" : {
        "definitions_from_file" : "/usr/local/etc/navel-scheduler/rabbitmq.json"
    },
    "webservices" : {
        "definitions_from_file" : "/usr/local/etc/navel-scheduler/webservices.json",
        "credentials" : {
            "login" : "admin",
            "password" : "password"
        },
        "mojo_server" : {
        }
    }
}
```
  - /scheduler/api/cron/jobs
```json
{
    "publishers" : [
        "rabbitmq-1",
        "rabbitmq-2"
    ],
    "connectors" : [
        "glpi-1",
        "collectd-1"
    ]
}

```
  - /scheduler/api/connectors
```json
[
    "glpi-1",
    "collectd-1"
]
```
  - /scheduler/api/connectors/(:connector)
```json
{
    "name" : "glpi-1",
    "collection" : "glpi",
    "type" : "code",
    "singleton" : 1,
    "scheduling" : "15 * * * * ?",
    "source" : "glpi",
    "input" : {
        "url" : "http://login:password@glpi.home.fr:8080"
    },
    "exec_directory_path" : "/usr/local/etc/navel-scheduler/connectors"
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
    "name" : "rabbitmq-1",
    "host" : "172.16.1.1",
    "port" : 5672,
    "user" : "guest",
    "password" : "guest",
    "timeout" : 0,
    "vhost" : "/",
    "tls" : 0,
    "heartbeat" : 30,
    "exchange" : "amq.topic",
    "delivery_mode" : 2,
    "scheduling" : "*/15 * * * * ?",
    "auto_connect" : 1
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
    "name" : "rabbitmq-1",
    "connected" : 0,
    "messages_in_queue" : 500
}
```
  - /scheduler/api/publishers/(:publisher)?action=clear_queue
```json
{
    "ok" : ["Clear queue for publisher rabbitmq-1"],
    "ko" : [],
    "name" : "rabbitmq-1",
    "connected" : 0,
    "messages_in_queue" : 0
}
```
  - /scheduler/api/publishers/(:publisher)?action=connect
```json
{
    "ok" : [],
    "ko" : [],
    "name" : "rabbitmq-1",
    "connected" : 1,
    "messages_in_queue" : 5
}
```
  - /scheduler/api/publishers/(:publisher)?action=disconnect
```json
{
    "ok" : [],
    "ko" : [],
    "name" : "rabbitmq-1",
    "connected" : 0,
    "messages_in_queue" : 0
}
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
        "name" : "webservice-1",
        "interface_mask" : "*",
        "port" : 22080,
        "tls" : 0,
        "ca" : null,
        "cert" : null,
        "ciphers" : null,
        "key" : null,
        "verify" : null
    }
]
```
- **POST** - create
  - /scheduler/api/connectors
```json
{
    "name" : "glpi-2",
    "collection" : "glpi",
    "type" : "code",
    "singleton" : 1,
    "scheduling" : "15 * * * * ?",
    "source" : "glpi",
    "input" : {
        "url" : "http://login:password@glpi2.home.fr:8080"
    }
}
```
  - /scheduler/api/rabbitmq
```json
{
    "name" : "rabbitmq-3",
    "host" : "172.16.1.3",
    "port" : 5672,
    "user" : "guest",
    "password" : "guest",
    "timeout" : 0,
    "vhost" : "/",
    "tls" : 0,
    "heartbeat" : 30,
    "exchange" : "amq.topic",
    "delivery_mode" : 2,
    "scheduling" : "*/15 * * * * ?",
    "auto_connect" : 1
}
```
  - /scheduler/api/publishers/(:publisher)
```json
{
    "datas" : [
        "foo",
        "bar"
    ],
    "collection" : "puppet-reports"
}
```
- **PUT** - modify
  - /scheduler/api/general/webservices/credentials
```json
{
    "password" : "new_password"
}
```
  - /scheduler/api/connectors/(:connector)
```json
{
    "scheduling" : "*/30 * * * * ?"
}
```
  - /scheduler/api/rabbitmq/(:rabbitmq)
```json
{
    "timeout" : 5
}
```
- **DEL** - delete
  - /scheduler/api/connectors/(:connector)
```json
{
    "ok" : [
        "Connector glpi-2 unregistered and deleted"
    ],
    "ko" : []
}
```
  - /scheduler/api/rabbitmq/(:rabbitmq)
```json
{
    "ok" : [
        "Publisher rabbitmq-3 disconnected, unregistered and deleted",
        "RabbitMQ rabbitmq-3 deleted"
    ],
    "ko" : []
}
```

Connectors
----------

Connectors are plain JSON files or Perl scripts which must contain a method named `connector`.

An exemple of Perl connector :

```perl
# pragmas strict and warnings + Navel::Utils are automatically loaded

#-> connector callback

sub connector {
    my ($connector_properties, $input) = @_;

    my @datas; # or retrieve datas from databases, message brokers, web services, ...

    AnyEvent::Fork::RPC::event("It's done father !") # send a log message to navel-scheduler

    \@datas;
}
```
