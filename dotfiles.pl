#!/usr/bin/env perl

use v5.24;
use warnings;
use autodie;
use lib 'lib';
use Util;

use Env qw(HOME);

if (-e "$HOME/config/backup") {
	print 'Backup directory exists! Really continue? (Y/n)';
	my $decision = readline STDIN;
	chomp $decision;
	die 'Aborted' unless $decision eq 'Y';
}

foreach my $dir ("$HOME/config/backup", "$HOME/.config", "$HOME/.config/nvim") {
	if (-e $dir && !-d $dir) {
		die "$dir is not a directory!";
	}

	mkdir $dir unless -d $dir;
}

my @filelist = (
	['neovim', "$HOME/.config/nvim/init.nvim"],
	['bashrc', "$HOME/.bashrc"],
	['vimrc', "$HOME/.vimrc"],
	['tmux.conf', "$HOME/.tmux.conf"],
	['xinitrc', "$HOME/.xinitrc"],
	['xbindkeysrc', "$HOME/.xbindkeysrc"],
	['gitignore', "$HOME/.gitignore"],
	['perltidyrc', "$HOME/.perltidyrc"],
	['profile', "$HOME/.profile"],
	['pcrd', "$HOME/.pcrd"],
);

foreach my $spec (@filelist) {
	my ($file, $dest) = @{$spec};

	rename $dest, "$HOME/config/backup/$file"
		if -e $dest || -l $dest;

	my @possible = ("dotfiles/$file", "../dotfiles/$file");
	my @contents = map { Util::slurp($_) } grep { -f } @possible;

	say "$file -> $dest...";
	Util::spew($dest, join "\n\n", @contents);
}

