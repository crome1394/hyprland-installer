#!/usr/bin/env bash

#Color helper
prompt_color() {
  local color="$1" msg="$2"
  local code reset
  case "$color" in
    black)   code=$'\e[30m' ;;
    magenta) code=$'\e[35m' ;;
    red)     code=$'\e[31m' ;;
    green)   code=$'\e[32m' ;;
    yellow)  code=$'\e[33m' ;;
    blue)    code=$'\e[34m' ;;
    cyan)    code=$'\e[36m' ;;
    white)   code=$'\e[37m' ;;
    bright)  code=$'\e[91m' ;;
    blink)   code=$'\e[5m' ;;
    *)       code=$'\e[0m' ;;
  esac
  reset=$'\e[0m'
  read -p "${code}${msg}${reset}" answer
}


# Install the essential *favorite* applications...
prompt_color bright "Do you want to install your favorite essental applications? "

if [[ $answer == "y" || $answer == "Y" ]]; 
then
    sudo pacman -S mpv \
               nm-connection-editor \
               cachy-update \
               vscodium \
               loupe \
               xpdf \
               quickshell \
               font-manager \
               protonup-qt \
               emby-theater \
               handbrake-cli \
               handbrake \
               flameshot \
               gvfs-mtp \
               gvfs-gphoto2 \
               mtpfs --noconfirm
     systemctl --user restart xdg-desktop-portal.service
	 systemctl --user restart xdg-desktop-portal-hyprland.service
else
    echo "Okay moving on..."
fi

# Start the necessary Services...
prompt_color bright "Do you want to start the hyprland necessary services? "

if [[ $answer == "y" || $answer == "Y" ]]; 
then
    systemctl --user enable --now hyprpolkitagent.service
    systemctl --user enable --now xdg-desktop-portal-hyprland.service
    systemctl --user enable --now xdg-desktop-portal.service
    systemctl --user enable --now xdg-desktop-portal-gtk.service
    systemctl --user enable --now xdg-desktop-portal-wlr.service
else
    echo "Okay moving on..."
fi

# install the hyprland plugins...
prompt_color bright "Do you want to install the hyprland plugins? "

if [[ $answer == "y" || $answer == "Y" ]]; 
then
    source hyprland-plugins.sh
else
    echo "Okay moving on..."
fi

# Install the profile sync daemon...
prompt_color bright "Do you want to install the Profile Sync Daemon? "

if [[ $answer == "y" || $answer == "Y" ]]; 
then
    source psd-installer.sh
else
    echo "Okay moving on..."
fi


# Install the screensaver...
prompt_color bright "Do you want to install the Screensaver? "

if [[ $answer == "y" || $answer == "Y" ]]; 
then
    source screensaver/install.sh
else
    echo "Okay moving on..."
fi

# Dolphin Open With (XDG application menu).
prompt_color bright "Do you want to apply Dolphin Open With (MIME) fixes? "

if [[ $answer == "y" || $answer == "Y" ]];
then
    source dolphin-fixes/install.sh
else
    echo "Okay moving on..."
fi

# Install the SDDM theme (run, do not source: that script re-execs itself as root).
prompt_color bright "Do you want to install the SDDM theme? "

if [[ $answer == "y" || $answer == "Y" ]]; 
then
    bash "$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)/sddm/install.sh"
else
    echo "Okay moving on..."
fi
