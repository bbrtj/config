#!/usr/bin/env bash

# Set up environment
export PATH=/usr/sbin:/sbin:$PATH

# system-independent stuff
git pull
git branch -d tmp
git worktree add -b tmp system-independent
cd system-independent
git branch --set-upstream-to=origin/system-independent system-independent
git checkout system-independent
cd ..

# fonts: https://docs.slackware.com/howtos:general_admin:install_fonts
sudo cp system-independent/fonts/icons.ttf /usr/share/fonts/TTF
sudo mkfontdir /usr/share/fonts/TTF
sudo mkfontscale /usr/share/fonts/TTF
sudo fc-cache -f -v

# LONG step - upgrade existing programs (deselect kernel or reboot after it's done)
wget https://www.slackpkg.org/stable/slackpkg-15.0.10-noarch-1.txz
sudo installpkg slackpkg-15.0.10-noarch-1.txz
rm slackpkg-15.0.10-noarch-1.txz
sudo slackpkg update
sudo slackpkg upgrade slackpkg
sudo slackpkg upgrade-all
# updatedb after reboot

# LONG step - compile programs
wget https://github.com/sbopkg/sbopkg/releases/download/0.38.3/sbopkg-0.38.3-noarch-1_wsr.tgz
sudo installpkg sbopkg-0.38.3-noarch-1_wsr.tgz
rm sbopkg-0.38.3-noarch-1_wsr.tgz
sudo sbopkg -r
sudo sqg -p "feh xbindkeys slock dunst flatpak borgbackup libqtpas rar unrar xsel docker cowsay" -o initial
sudo sbopkg -i initial

# configure flatpak
sudo flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo

# games play without permission issues
sudo chgrp -R users /var/lib/bsdgames
sudo chmod -R g+w /var/lib/bsdgames

# disable elogind
sudo chmod -x /etc/rc.d/rc.elogind

# install crontab
sudo crontab slack_crontab

cp local_config.example.sh local_config.sh

