package Workaholicd::State;
use strict;
use warnings;
use Dongry::Database;
use Web::UserAgent::Functions qw(http_post);
use JSON::Functions::XS qw(perl2json_bytes);
use Data::Dumper;
use Scalar::Util qw(weaken);
use Workaholicd::Main;

my $LastTaskID = 0;

sub new_from_taskdef {
    my $state = bless {def => $_[1], task_id => ++$LastTaskID}, $_[0];
    return $state;
}

sub task_id {
    return $_[0]->{task_id};
}

sub schedule_next {
    my ($state, $cv) = @_;
    if ($state->{stop}) {
        delete $state->{timer};
    } else {
        $cv->begin;
        $state->{timer} = AnyEvent->timer(after => $state->{def}->{interval}, cb => sub {
            $state->action(sub {
                $state->schedule_next($cv);
                $cv->end;
            });
        });
    }
}

sub db {
    my ($self, $name) = @_;
    weaken($self = $self);
    return $self->{dbs}->{$name} ||= do {
        my $dsn = $self->{def}->{dsns}->{$name}
            or die "dsn of name |$name| is not defined";
        Dongry::Database->new(sources => {
            default => {
                dsn => $dsn,
            },
        }, onerror => sub {
            my ($db, %args) = @_;
            $self->write_log(
                message => 'SQL error: ' . $args{text},
                details => {
                    response => \%args,
                },
            );
        });
    };
}

sub action {
    my ($state, $code) = @_;

    my @def = @{$state->{def}->{actions}};
    my $def = $def[rand @def];

    my $db = $state->db($def->{db});
    eval {
        unless ($db->has_table($def->{table_name})) {
            $code->() if $code;
            return;
        }

    $db->execute(
        $def->{sql}, {
            table_name => $def->{table_name},
            %{($def->{get_sql_args} or sub { +{} })->()},
        },
        cb => sub {
            my ($db, $result) = @_;
            if ($result->is_success) {
                if ($def->{heartbeat} or $result->row_count) {
                    my $json = perl2json_bytes {
                        args => $def->{args},
                        row_count => $result->row_count,
                    };
                    http_post
                        anyevent => 1,
                        url => $def->{url},
                        basic_auth => $def->{basic_auth},
                        header_fields => {
                            'Content-Type' => 'application/json',
                        },
                        content => $json,
                        cb => sub {
                            my ($req, $res) = @_;
                            unless ($res->is_success) {
                                $state->write_log(
                                    message => 'HTTP error: ' . $res->status_line,
                                    details => {
                                        url => $def->{url},
                                        args => $def->{args},
                                        response => $res->as_string,
                                    },
                                );
                            }
                            $code->();
                            undef $code;
                        };
                } else {
                    $code->();
                    undef $code;
                }
            } else {
                $state->write_log(
                    message => 'SQL error: ' . $result->error_text,
                    details => {
                        url => $def->{url},
                        args => $def->{args},
                        response => $result->debug_info,
                    },
                );
                $code->();
                undef $code;
            }
        },
    );
        1;
    } or do {
        $code->() if $code;
    };
}

sub write_log {
    my ($self, %args) = @_;
    printf STDERR "[%s] %s/whd/%s/%s: %s\n",
        scalar gmtime,
        $Workaholicd::Main::Hostname,
        $$,
        $self->task_id,
        $args{message};
    if ($args{details}) {
        print STDERR Dumper $args{details};
    }
}

1;
