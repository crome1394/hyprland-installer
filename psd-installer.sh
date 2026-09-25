#!/usr/bin/env bash

# Install the profile sync daemon
sudo pacman -S profile-sync-daemon

# Adding Profile-sync-daemon browser support for Brave...
sudo tee /usr/share/psd/browsers/test-brave << 'EOF'
DIRArr[0]="$XDG_CONFIG_HOME/BraveSoftware/Brave-Browser"
PSNAME="brave"
EOF

# Adding Profile-sync-daemon browser support for Brave-Origin...
sudo tee /usr/share/psd/browsers/brave-origin << 'EOF'
DIRArr[0]="$XDG_CONFIG_HOME/BraveSoftware/Brave-Origin"
PSNAME="brave-origin"
EOF
