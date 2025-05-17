#!/usr/bin/env sh

git config --global core.excludesfile ~/.gitignore

git clone --depth 1 https://github.com/junegunn/fzf.git ~/.fzf
~/.fzf/install

mkdir -p ~/.dzil
git clone https://github.com/bbrtj/perl-dzil-profiles ~/.dzil/profiles

\curl -L https://install.perlbrew.pl | bash

