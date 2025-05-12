#!/usr/bin/env sh

# xhost + local:
# export DISPLAY=localhost:0
export MON_CONFIG="HDMI-1,DP-1;LVDS-1;left"
export WALLPAPER="$HOME/pix/wallpaper.jpg"
export LC_CTYPE=pl_PL.UTF-8
export LANG=pl_PL.UTF-8

# fix DWM java apps
export _JAVA_AWT_WM_NONREPARENTING=1

. ~/config/local_tweaks.sh
#export DMENU_FAVS="firefox thunderbird ovoplayer calc lazarus dbeaver doublecmd transmission file-roller pavucontrol nm-applet blueman-applet eboard xnethack xadventure gvim gcolor thunar xfce4-clipman fpcupdeluxe"

