#!/usr/bin/env bash

# Set up environment

# system-independent stuff
git pull
git worktree add system-independent

# fonts: https://docs.slackware.com/howtos:general_admin:install_fonts
sudo cp system-independent/fonts/icons.ttf /usr/share/fonts/TTF
mkfontdir /usr/share/fonts/TTF
mkfontscale /usr/share/fonts/TTF
fc-cache -f -v

# LONG step - upgrade existing programs (deselect kernel or reboot after it's done)
wget https://www.slackpkg.org/stable/slackpkg-15.0.10-noarch-1.txz
sudo installpkg slackpkg-15.0.10-noarch-1.txz
rm https://www.slackpkg.org/stable/slackpkg-15.0.10-noarch-1.txz
sudo slackpkg update
sudo slackpkg upgrade slackpkg
sudo slackpkg upgrade-all
# updatedb after reboot

# LONG step - compile programs
wget https://github.com/sbopkg/sbopkg/releases/download/0.38.3/sbopkg-0.38.3-noarch-1_wsr.tgz
sudo installpkg sbopkg-0.38.3-noarch-1_wsr.tgz
rm sbopkg-0.38.3-noarch-1_wsr.tgz
sudo sbopkg -r
sudo sqg -p "feh xbindkeys slock flatpak borgbackup libqtpas rar unrar xsel docker" -o initial
sudo sbopkg -i initial

# configure flatpak
sudo flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo

# games play without permission issues
sudo chgrp -R users /var/lib/bsdgames
sudo chmod -R g+w /var/lib/bsdgames

cp local_config.example.sh local_config.sh

