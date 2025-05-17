#!/usr/bin/env sh

if [ -d ~/config/backup ]; then
	echo 'Abort: backup directory exists!'
	exit 1
fi

mkdir ~/config/backup
mkdir -p ~/.config/nvim

mv ~/.config/nvim/init.vim ~/config/backup/
mv ~/.bashrc ~/config/backup/
mv ~/.vimrc ~/config/backup/
mv ~/.tmux.conf ~/config/backup/
mv ~/.xinitrc ~/config/backup/
mv ~/.xbindkeysrc ~/config/backup/
mv ~/.gitignore ~/config/backup/
mv ~/.perltidyrc ~/config/backup/
mv ~/.profile ~/config/backup/
mv ~/.pcrd ~/config/backup/

ln -s ~/config/dotfiles/neovim ~/.config/nvim/init.vim
ln -s ~/config/dotfiles/bashrc ~/.bashrc
ln -s ~/config/dotfiles/vimrc ~/.vimrc
ln -s ~/config/dotfiles/tmux.conf ~/.tmux.conf
ln -s ~/config/dotfiles/xinitrc ~/.xinitrc
ln -s ~/config/dotfiles/xbindkeysrc ~/.xbindkeysrc
ln -s ~/config/dotfiles/gitignore ~/.gitignore
ln -s ~/config/dotfiles/perltidyrc ~/.perltidyrc
ln -s ~/config/dotfiles/profile ~/.profile
ln -s ~/config/dotfiles/pcrd ~/.pcrd

