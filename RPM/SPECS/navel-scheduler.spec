# Navel Scheduler is developped by Yoann Le Garff, Nicolas Boquet and Yann Le Bras under GNU GPL v3

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

Requires:    perl => 5.10.1-1, perl(Scalar::Util::Numeric), perl(IO::File), perl(File::Slurp), perl(Safe), perl(IPC::Cmd), perl(Net::AMQP::RabbitMQ), perl(Carp), perl(EV), perl(AnyEvent::Datetime::Cron), perl(Exporter::Easy), perl(Storable), perl(Data::Validate::Struct), perl(Scalar::Util), perl(JSON), perl(DateTime::Event::Cron::Quartz), perl(List::MoreUtils), perl(String::Util), perl(Cwd), perl(Proc::Daemon), perl(Mojolicious)

%description
"navel-scheduler's purpose is to get back datas from connectors at scheduled time then encode and push it through RabbbitMQ to navel-router"

%prep
%setup -c

%install
%__cp -a . "${RPM_BUILD_ROOT-/}"

%clean
[ "${RPM_BUILD_ROOT}" != '/' ] && rm -rf "${RPM_BUILD_ROOT}"

%post
chkconfig --level 234 navel-scheduler on

%files
%defattr(-, root, root)

/etc/sysconfig/*
%attr(755, -, -) /etc/init.d/*
/usr/local/etc/navel-scheduler/*
%attr(755, -, -) /usr/local/bin/*
/usr/local/share/navel-scheduler/lib/*
%dir% /var/log/navel-scheduler/

#-> END
