# Copyright 2015 Navel-IT
# navel-scheduler is developed by Yoann Le Garff, Nicolas Boquet and Yann Le Bras under GNU GPL v3

#-> BEGIN

#-> initialization

package Navel::Scheduler::Parser 0.1;

use Navel::Base;

use parent qw/
    Navel::Base::Definition::Parser::Reader
    Navel::Base::Definition::Parser::Writer
/;

use Navel::Base::Definition;

#-> methods

sub new {
    my $class = shift;

    bless {
        definition => {}
    }, ref $class || $class;
}

sub validate {
    my ($class, $raw_definition) = @_;

    Navel::Base::Definition->validate(
        definition_class => __PACKAGE__,
        validator => {
            type => 'object',
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
                    required => [
                        qw/
                            definitions_from_file
                            collectors_exec_directory
                            maximum
                            maximum_simultaneous_exec
                            execution_timeout
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
                        collectors_exec_directory => {
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
                        },
                        maximum_simultaneous_exec => {
                            type => 'integer',
                            minimum => 0
                        },
                        execution_timeout => {
                            type => 'integer',
                            minimum => 0
                        }
                    }
                },
                publishers => {
                    type => 'object',
                    required => [
                        qw/
                            definitions_from_file
                            maximum
                            maximum_simultaneous_exec
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
                        },
                        maximum_simultaneous_exec => {
                            type => 'integer',
                            minimum => 0
                        }
                    }
                },
                webservices => {
                    type => 'object',
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
                            properties => {
                                reverse_proxy => {
                                    type => 'integer'
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
                                },
                                accepts => {
                                    type => 'integer'
                                },
                                accept_interval => {
                                    type => 'number'
                                },
                                graceful_timeout => {
                                    type => 'number'
                                },
                                heartbeat_interval => {
                                    type => 'number'
                                },
                                heartbeat_timeout => {
                                    type => 'number'
                                },
                                multi_accept => {
                                    type => 'integer'
                                },
                                workers => {
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

sub set_definition {
    my ($self, $value) = @_;

    my $errors = $self->validate($value);

    die $errors if @{$errors};

    $self->{definition} = $value;

    $self;
}

sub read {
    my $self = shift;

    $self->set_definition($self->SUPER::read(@_));

    $self;
}

sub write {
    my $self = shift;

    $self->SUPER::write(
        definitions => $self->{definition},
        @_
    );

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

Navel::Scheduler::Parser

=head1 AUTHOR

Yoann Le Garff, Nicolas Boquet and Yann Le Bras

=head1 LICENSE

GNU GPL v3

=cut
