#!/usr/bin/env bash

# Install the essentials
sudo pacman -S hyprpolkitagent \
               hypridle \
               hyprlock \
               hyprpaper \
               hyprpicker \
			   hyprpm \
               xdg-desktop-portal-hyprland \
               xdg-desktop-portal-gtk \
               xdg-desktop-portal \
               xdg-desktop-portal-wlr \
               grim \
               slurp \
               swaync \
               swayosd \
               rofi \
               qt6ct \
               fuse2 \
               gvfs \
               sddm \
               cachy-update \
               wl-clipboard \
               kvantum \
               ark \
               unzip \
               p7zip \
               unrar \
               bat \
               glow \
               flatpak \
               zoxide \
               starship \
               nvtop \
               htop \
               atop \
               nmon \
               iotop \
               iftop \
               powertop \
               fd \
               fzf \
               paru \
               nano-syntax-highlighting --noconfirm

# Install the coding essentials
sudo pacman -S --needed base-devel cmake git pkgconf openssl cpio gcc ccache --noconfirm

# Change shell to BASH
chsh -s /usr/bin/bash

# Create the mount points
sudo mkdir -p /mnt/media-a
sudo mkdir -p /mnt/media-b
sudo mkdir -p /mnt/media-c
sudo mkdir -p /mnt/media-d
sudo mkdir -p /mnt/media-e
sudo mkdir -p /mnt/media-f
sudo mkdir -p /mnt/media-g
sudo mkdir -p /mnt/media-h
sudo mkdir -p /mnt/tera-a
sudo mkdir -p /mnt/tera-b

# Automatically create the mount directories
sudo tee /etc/tmpfiles.d/keep-crome-media-dirs.conf << 'EOF'
# Recreate /run/media/crome and your NFS mountpoint directories at boot
d /run/media/crome        0755 crome crome -
d /run/media/crome/tera-a 0755 crome crome -
d /run/media/crome/tera-b 0755 crome crome -
d /run/media/crome/tera-c 0755 crome crome -
d /run/media/crome/tera-d 0755 crome crome -
	  
# Marker file — prevents udisksd/stale cleanup from removing the dir when unmounted
f /run/media/crome/tera-a/.keep 0644 crome crome - "Marker file to keep mountpoint directory from being auto-removed by udisksd"
f /run/media/crome/tera-b/.keep 0644 crome crome - "Marker file to keep mountpoint directory from being auto-removed by udisksd"
f /run/media/crome/tera-c/.keep 0644 crome crome - "Marker file to keep mountpoint directory from being auto-removed by udisksd"
f /run/media/crome/tera-d/.keep 0644 crome crome - "Marker file to keep mountpoint directory from being auto-removed by udisksd"
EOF
sudo systemd-tmpfiles --create /etc/tmpfiles.d/keep-crome-media-dirs.conf

# Update the hosts file
sudo bash -c 'cat << EOF >> /etc/hosts

10.74.10.30  nas.local nas.lan crome.local crome.lan crome-nas
10.74.10.31  media.local media.lan media-nas
EOF'

# Update the fstab file
sudo bash -c 'cat << EOF >> /etc/fstab

# Secondary Internal SSDs
UUID=808272be-f566-48fa-803d-dfdb6a38b765 /run/media/crome/data ext4 defaults,auto,user,nosuid,nodev,exec,nofail,x-gvfs-show 0 0

# On-demand NFS shares (mountable by user via file manager or mount command) 
nas.local:/volume1/tera-a /run/media/crome/tera-a nfs _netdev,nofail,noauto,user,nosuid,nodev,exec,rsize=1048576,wsize=1048576,actimeo=60,vers=4 0 0
nas.local:/volume2/tera-b /run/media/crome/tera-b nfs _netdev,nofail,noauto,user,nosuid,nodev,exec,rsize=1048576,wsize=1048576,actimeo=60,vers=4 0 0
# nas.local:/volume3/tera-c /run/media/crome/tera-c nfs _netdev,nofail,noauto,user,nosuid,nodev,exec,rsize=1048576,wsize=1048576,actimeo=60,vers=4 0 0' aa

# Secondary Internal SSDs
UUID=808272be-f566-48fa-803d-dfdb6a38b765 /run/media/crome/data ext4 defaults,auto,user,nosuid,nodev,exec,nofail,x-gvfs-show 0 0

# On-demand NFS shares (mountable by user via file manager or mount command) 
nas.local:/volume1/tera-a /run/media/crome/tera-a nfs _netdev,nofail,noauto,user,nosuid,nodev,exec,rsize=1048576,wsize=1048576,actimeo=60,vers=4 0 0
nas.local:/volume2/tera-b /run/media/crome/tera-b nfs _netdev,nofail,noauto,user,nosuid,nodev,exec,rsize=1048576,wsize=1048576,actimeo=60,vers=4 0 0
# nas.local:/volume3/tera-c /run/media/crome/tera-c nfs _netdev,nofail,noauto,user,nosuid,nodev,exec,rsize=1048576,wsize=1048576,actimeo=60,vers=4 0 0
EOF'

systemctl --user daemon-reload

# Enable the sddm service and start the GUI
sudo systemctl enable sddm
#read -r -p "Press enter to continue..."
echo sudo systemctl start sddm or Reboot
