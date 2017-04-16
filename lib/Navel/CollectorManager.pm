# Copyright (C) 2015-2017 Yoann Le Garff, Nicolas Boquet and Yann Le Bras
# navel-collector-manager is licensed under the Apache License, Version 2.0

#-> BEGIN

#-> initialization

package Navel::CollectorManager 0.1;

use Navel::Base;

use parent 'Navel::Base::WorkerManager';

use File::ShareDir 'dist_dir';

use Navel::CollectorManager::Parser;
use Navel::API::OpenAPI::CollectorManager;

#-> class variables

sub run {
    my $class = shift;

    $class->SUPER::run(
        @_,
        program_name => 'navel-collector-manager'
    );
}

sub new {
    my $class = shift;

    state $self = $class->SUPER::new(
        @_,
        meta => Navel::CollectorManager::Parser->new,
        core_class => 'Navel::CollectorManager::Core',
        mojolicious_application_class => 'Navel::CollectorManager::Mojolicious::Application',
        mojolicious_application_home_directory => dist_dir('Navel-CollectorManager') . '/mojolicious/home',
        openapi_url => Navel::API::OpenAPI::CollectorManager->spec_file_location
    );

    $self->{webserver}->app->mode('production') if $self->webserver;

    $self;
}

sub start {
    my $self = shift;

    $self->SUPER::start(@_)->{core}->recv;

    $self;
}

# sub AUTOLOAD {}

# sub DESTROY {}

1;

#-> END

__END__

=pod

=encoding utf8

=head1 NAME

Navel::CollectorManager

=head1 COPYRIGHT

Copyright (C) 2015-2017 Yoann Le Garff, Nicolas Boquet and Yann Le Bras

=head1 LICENSE

navel-collector-manager is licensed under the Apache License, Version 2.0

=cut
