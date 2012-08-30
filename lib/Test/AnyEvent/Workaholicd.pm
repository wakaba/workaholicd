package Test::AnyEvent::Workaholicd;
use strict;
use warnings;
our $VERSION = '1.0';
use AnyEvent;
use AnyEvent::Util;
use File::Temp;
use Path::Class;

sub new_from_root_d {
    return bless {root_d => $_[1]}, $_[0];
}

sub root_d {
    return $_[0]->{root_d};
}

# ------ Options ------

sub server_pl_f {
    my $self = shift;
    if (@_) {
        $self->{server_pl_f} = shift;
    }
    return $self->{server_pl_f} ||= $self->root_d->file('bin', 'workaholicd.pl');
}

sub config_pl_f {
    my $self = shift;
    if (@_) {
        $self->{config_pl_f} = shift;
    }
    return $self->{config_pl_f} ||= $self->root_d->file('config', 'workaholicd.pl');
}

sub set_config_code {
    my ($self, $code) = @_;
    my $temp = $self->{config_file_temp} = File::Temp->new;
    binmode $temp, ':utf8';
    print $temp $code;
    close $temp;
    $self->{config_pl_f} = file($temp->filename);
}

sub set_env {
    $_[0]->{envs}->{$_[1]} = $_[2];
}

sub envs {
    return (%ENV, %{$_[0]->{envs} or {}});
}

# ------ Server ------

sub onstdout {
    if (@_ > 1) {
        $_[0]->{onstdout} = $_[1];
    }
    return $_[0]->{onstdout};
}

sub onstderr {
    if (@_ > 1) {
        $_[0]->{onstderr} = $_[1];
    }
    return $_[0]->{onstderr};
}

sub start_server {
    my $self = shift;
    
    my $pid;
    my $stop_cv = run_cmd
        [
            'perl',
            $self->server_pl_f->stringify, 
            $self->config_pl_f->stringify,
        ],
        '>' => $self->onstdout || *STDOUT,
        '2>' => $self->onstderr || *STDERR,
        '$$' => \$pid;
    $self->{pid} = $pid;

    my $start_cv = AE::cv;
    $start_cv->send;

    return ($start_cv, $stop_cv);
}

sub stop_server {
    my $self = shift;
    if ($self->{pid}) {
        kill 15, $self->{pid}; # SIGTERM
    }
}

sub pid {
    return $_[0]->{pid};
}

sub DESTROY {
    $_[0]->stop_server;
}

1;
