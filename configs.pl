#!/usr/bin/perl

use v5.24;
use warnings;
use File::Copy qw(copy);

my @configs = glob "../configs/*";

foreach my $from (sort @configs) {
	my $to = $from =~ s{\$\$}{/}gr;
	$to =~ s{^../configs}{};

	say "copying $from to $to...";
	copy($from, $to) or die "Could not copy, need to be root?";
}

