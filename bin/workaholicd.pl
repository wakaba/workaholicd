#!/usr/bin/perl
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
use Workaholicd::Main;
use Path::Class;

my $config_pl_name = shift or die "Usage: $0 config.pl\n";

my $whd = Workaholicd::Main->new;
$whd->tasks_f(file($config_pl_name));
$whd->process;
