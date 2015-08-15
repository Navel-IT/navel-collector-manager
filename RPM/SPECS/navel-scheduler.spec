# Navel Scheduler is developed by Yoann Le Garff, Nicolas Boquet and Yann Le Bras under GNU GPL v3

#-> BEGIN

Name:    navel-scheduler
Version:    %{_version}
Release:    %{_release}
Summary:    navel-scheduler
License:    GNU GPL v3
URL:    http://github.com/navel-it/navel-scheduler
Source:    navel-scheduler.tar.gz
Prefix:    /opt
BuildRoot:      %{_tmppath}/%{name}
BuildArch:    noarch

Requires:    bash, perl >= 5.10.1-1, perl(Scalar::Util::Numeric), perl(File::Slurp), perl(IO::AIO), perl(JSON), perl(IPC::Cmd), perl(Carp), perl(EV), perl(AnyEvent::Datetime::Cron), perl(AnyEvent::RabbitMQ) >= 1.19, perl(AnyEvent::AIO), perl(AnyEvent::Fork), perl(AnyEvent::Fork::RPC), perl(Exporter::Easy), perl(Storable), perl(Data::Validate::Struct), perl(Scalar::Util), perl(DateTime::Event::Cron::Quartz), perl(Pod::Usage), perl(List::MoreUtils), perl(Cwd), perl(Proc::Daemon), perl(Mojolicious), perl(Time::HiRes), perl(Compress::Raw::Zlib), perl(IO::Compress::Gzip)

%description
"navel-scheduler's purpose is to get back datas from connectors at scheduled time then encode and push it through RabbbitMQ to navel-router"

%prep
%setup -c

%install
%__cp -a . "${RPM_BUILD_ROOT-/}"

%clean
[ "${RPM_BUILD_ROOT}" != '/' ] && rm -rf "${RPM_BUILD_ROOT}"

%pre
getent group navel-scheduler || groupadd -r navel-scheduler
getent passwd navel-scheduler || useradd -rmd /usr/local/etc/navel-scheduler/ -s /sbin/nologin navel-scheduler

%post
chkconfig navel-scheduler on

%files
%defattr(-, navel-scheduler, navel-scheduler)

%dir% /usr/local/share/navel-scheduler
%dir% /var/run/navel-scheduler/
%dir% /var/log/navel-scheduler/

%attr(-, root, root) /etc/sysconfig/navel-scheduler
%attr(755, root, root) /etc/init.d/navel-scheduler
/usr/local/etc/navel-scheduler/*
%attr(755, -, -) /usr/local/bin/navel-scheduler
/usr/local/share/navel-scheduler/lib/*

%postun
groupdel navel-scheduler
userdel navel-scheduler

#-> END
