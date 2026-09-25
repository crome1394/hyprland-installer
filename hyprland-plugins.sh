#!/usr/bin/env bash

echo "Adding plugin repositories..."
# Add repositories 
hyprpm add https://github.com/fedsfarm/gloview
hyprpm add https://github.com/hyprwm/hyprland-plugins

echo "Updating headers..."
# This single update will pull, build, and package BOTH repositories at once
hyprpm update -v

echo "Activating plugins..."
# Enable them sequentially (this just changes symlinks/configs, no re-compile)
hyprpm enable gloview
hyprpm enable hyprbars

echo "Reloading Hyprland plugin manager..."
hyprpm reload

echo "All plugins successfully installed and activated!"
