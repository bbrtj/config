package Util;

use v5.24;
use warnings;
use autodie;

sub slurp
{
	my ($file) = @_;

	open my $fh, '<', $file;
	local $/;
	return scalar readline $fh;
}

sub spew
{
	my ($file, $contents) = @_;

	open my $fh, '>', $file;
	print {$fh} $contents;
}

1;

