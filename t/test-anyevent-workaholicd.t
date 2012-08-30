use strict;
BEGIN {
    my $file_name = __FILE__;
    $file_name =~ s{[^/]+$}{};
    $file_name ||= '.';
    $file_name .= '/../config/perl/libs.txt';
    open my $file, '<', $file_name or die "$0: $file_name: $!";
    unshift @INC, split /:/, scalar <$file>;
}
use warnings;
use Path::Class;
use lib glob file(__FILE__)->dir->subdir('modules', '*', 'lib')->stringify;
use Test::More;
use Test::X1;
use Test::AnyEvent::Workaholicd;

my $root_d = file(__FILE__)->dir->resolve->parent;

test {
    my $c = shift;

    my $server = Test::AnyEvent::Workaholicd->new_from_root_d($root_d);
    my ($start_cv, $stop_cv) = $server->start_server;

    $start_cv->cb(sub {
        test {
            my $pid = $server->pid;
            ok $pid;
        } $c;
    });

    $stop_cv->cb(sub {
        my $return = $_[0]->recv;
        test {
            ok $return >> 8;
            my $pid = $server->pid;
            ok !kill 0, $pid;
            done $c;
            undef $c;
        } $c;
    });
} n => 3, name => 'default (config.pl not found)';

test {
    my $c = shift;

    my $server = Test::AnyEvent::Workaholicd->new_from_root_d($root_d);
    $server->set_config_code(q{
        return [];
    });

    my ($start_cv, $stop_cv) = $server->start_server;

    $start_cv->cb(sub {
        test {
            ok $server->pid;
            my $timer; $timer = AE::timer 0.5, 0, sub {
                test {
                    $server->stop_server;
                    undef $timer;
                } $c;
            };
        } $c;
    });

    $stop_cv->cb(sub {
        my $return = $_[0]->recv;
        test {
            is $return >> 8, 0;
            my $pid = $server->pid;
            ok !kill 0, $pid;
            done $c;
            undef $c;
        } $c;
    });
} n => 3, name => 'set_config_code (empty)';

run_tests;
