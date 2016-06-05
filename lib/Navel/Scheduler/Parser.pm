# Copyright (C) 2015 Yoann Le Garff, Nicolas Boquet and Yann Le Bras
# navel-scheduler is licensed under the Apache License, Version 2.0

#-> BEGIN

#-> initialization

package Navel::Scheduler::Parser 0.1;

use Navel::Base;

use parent 'Navel::Base::Daemon::Parser';

#-> methods

sub validate {
    my ($class, $raw_definition) = @_;

    $class->SUPER::validate(
        @_,
        validator => {
            type => 'object',
            additionalProperties => 0,
            required => [
                qw/
                    collectors
                    publishers
                    webservices
                /
            ],
            properties => {
                collectors => {
                    type => 'object',
                    additionalProperties => 0,
                    required => [
                        qw/
                            definitions_from_file
                            maximum
                        /
                    ],
                    properties => {
                        definitions_from_file => {
                            type => [
                                qw/
                                    string
                                    integer
                                    number
                                /
                            ]
                        },
                        maximum => {
                            type => 'integer',
                            minimum => 0
                        }
                    }
                },
                publishers => {
                    type => 'object',
                    additionalProperties => 0,
                    required => [
                        qw/
                            definitions_from_file
                            maximum
                        /
                    ],
                    properties => {
                        definitions_from_file => {
                            type => [
                                qw/
                                    string
                                    integer
                                    number
                                /
                            ]
                        },
                        maximum => {
                            type => 'integer',
                            minimum => 0
                        }
                    }
                },
                webservices => {
                    type => 'object',
                    additionalProperties => 0,
                    required => [
                        qw/
                            definitions_from_file
                            credentials
                            mojo_server
                        /
                    ],
                    properties => {
                        definitions_from_file => {
                            type => [
                                qw/
                                    string
                                    integer
                                    number
                                /
                            ]
                        },
                        credentials => {
                            type => 'object',
                            additionalProperties => 0,
                            required => [
                                qw/
                                    login
                                    password
                                /
                            ],
                            properties => {
                                login => {
                                    type => [
                                        qw/
                                            string
                                            integer
                                            number
                                        /
                                    ]
                                },
                                password => {
                                    type => [
                                        qw/
                                            string
                                            integer
                                            number
                                        /
                                    ]
                                }
                            }
                        },
                        mojo_server => {
                            type => 'object',
                            additionalProperties => 0,
                            properties => {
                                reverse_proxy => {
                                    type => 'integer',
                                    minimum => 0,
                                    maximum => 1
                                },
                                backlog => {
                                    type => 'integer'
                                },
                                inactivity_timeout => {
                                    type => 'integer'
                                },
                                max_clients => {
                                    type => 'integer'
                                },
                                max_requests => {
                                    type => 'integer'
                                }
                            }
                        }
                    }
                }
            }
        },
        raw_definition => $raw_definition
    );
}

# sub AUTOLOAD {}

# sub DESTROY {}

1;

#-> END

__END__

=pod

=encoding utf8

=head1 NAME

Navel::Scheduler::Parser

=head1 COPYRIGHT

Copyright (C) 2015 Yoann Le Garff, Nicolas Boquet and Yann Le Bras

=head1 LICENSE

navel-scheduler is licensed under the Apache License, Version 2.0

=cut
