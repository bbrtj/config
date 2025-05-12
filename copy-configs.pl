#!/usr/bin/perl

use v5.24;
use warnings;
use File::Copy qw(copy);

my @configs = glob "slackware/configs/*";

foreach my $from (sort @configs) {
	my $to = $from =~ s{\$\$}{/}gr;
	$to =~ s{^slackware/configs}{};

	say "copying $from to $to...";
	copy($from, $to) or die "Could not copy, need to be root?";
}

