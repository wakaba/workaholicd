package Workaholicd::Main;
use strict;
use warnings;
use AnyEvent;
use Sys::Hostname;
use Workaholicd::State;

our $Hostname = hostname;

sub new {
    my $class = shift;
    return bless {@_, states => []}, $class;
}

sub tasks_f {
    if (@_ > 1) {
        $_[0]->{tasks_f} = $_[1];
    }
    return $_[0]->{tasks_f};
}

sub load_tasks {
    my $self = shift;
    $self->write_log(message => 'Loading task definitions from ' . $self->{tasks_f}->stringify . '...');
    my $tasks = do($self->{tasks_f}->stringify)
        or die "$0: @{[$self->{tasks_f}]}: $!$@\n";
    for my $task (@$tasks) {
        my $state = Workaholicd::State->new_from_taskdef($task);
        $state->schedule_next($self->{cv});
        push @{$self->{states}}, $state;
    }
    unless (@$tasks) {
        $self->write_log(message => "No task returned by $self->{tasks_f}");
        die "No task returned by $self->{tasks_f}";
    }
    undef $self->{load_timer};
}

sub stop_tasks {
    my $self = shift;
    for (@{$self->{states}}) {
        $_->{stop} = 1;
    }
    @{$self->{states}} = ();
}

sub handle_signal {
    my ($self, $type) = @_;
    $self->write_log(message => 'Received SIG' . $type);
    $self->stop_tasks;

    if ($type eq 'HUP') {
        $self->{cv}->begin;
        $self->{load_timer} = AnyEvent->timer(after => 0, cb => sub {
            $self->load_tasks;
            $self->{cv}->end;
        });
    } else {
        $self->{stop} = 1;
        @{$self->{signal_watchers}} = ();
    }
}

sub process {
    my $self = shift;
    $self->write_log(message => 'Started');
    
    my $cv = $self->{cv} = AnyEvent->condvar;
    $cv->begin;
    
    my $states = $self->{states} = [];
    $self->load_tasks;

    my @w;
    $self->{signal_watchers} = \@w;
    for my $sig (qw(INT TERM QUIT HUP)) {
        push @w, AnyEvent->signal(
            signal => $sig, cb => sub { $self->handle_signal($sig) },
        );
    }
    
    $cv->end;
    $cv->recv;
    $self->write_log(message => 'Stopped');

    delete $self->{cv};
    delete $self->{states};
    delete $self->{load_timer};
    delete $self->{signal_watchers};
}

sub write_log {
    my ($self, %args) = @_;
    printf STDERR "[%s] %s/whd/%s: %s\n",
        scalar gmtime,
        $Hostname,
        $$,
        $args{message};
}

1;
