#!/usr/bin/perl

use v5.24;
use warnings;
use File::Path qw(mkpath);
use File::Basename qw(dirname);
use lib 'lib';
use Util;

my @configs = (glob("configs/*"), glob("../configs/*"));
my %loaded;

foreach my $from (@configs) {

	my $to = $from =~ s{\$\$}{/}gr;
	$to =~ s{^(.+/)?configs}{};
	my $mode = (stat $from)[2] & 0777;
	my $data = Util::slurp($from);

	if (!$loaded{$to}) {
		$loaded{$to} = {
			mode => $mode,
			data => $data,
		};
	}
	else {
		die "mismatch mode for $to"
			unless $loaded{$to}{mode} == $mode;

		$loaded{$to}{data} .= "\n\n" . $data;
	}
}

foreach my $to (sort keys %loaded) {
	say sprintf "creating %s (mode %04o)...", $to, $loaded{$to}{mode};
	my $dir = dirname $to;
	if (!-d $dir) {
		say "making new directory $dir";
		mkpath $dir;
	}

	Util::spew($to, $loaded{$to}{data});
	chmod $loaded{$to}{mode}, $to or die "Could not chmod";
}

