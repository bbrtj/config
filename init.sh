#!/usr/bin/env sh

# Set up environment

doas pkg install git xorg ncurses tmux pkgconf freetype2 fontconfig patch tree universal-ctags htop neofetch xbindkeys stalonetray the_silver_searcher firefox xf86-video-intel slock dmenu intel-backlight wpa_supplicant_gui freefont-ttf libsynaptics slim slim-freebsd-dark-theme pavucontrol xclip thunderbird gimp-app feh gmp gnome-screenshot bash xcompmgr neovim fusefs-ntfs drm-kmod twemoji-color-font-ttf ja-font-std zh-font-std fonts-indic webcamd v4l-utils v4l_compat hs-pandoc doublecmd py311-trash-cli mplayer

ln -s /usr/local/bin/ranger ~/bin/list

git worktree add system-independent

# next steps:
# ~/config/system-independent/init.sh
# ~/config/system-independent/dotfiles.sh
# ~/config/system-independent/vim.sh
# adjust local_config.sh

