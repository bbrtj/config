#!/usr/bin/perl

use v5.24;
use warnings;
use File::Copy qw(copy);

my @configs = glob "../configs/*";

foreach my $from (sort @configs) {
	my $to = $from =~ s{\$\$}{/}gr;
	$to =~ s{^../configs}{};

	my $mode = (stat $from)[2] & 0777;

	say sprintf "copying %s to %s (mode %04o)...", $from, $to, $mode;
	copy($from, $to) or die "Could not copy, need to be root?";
	chmod $mode, $to or die "Could not chmod";
}

