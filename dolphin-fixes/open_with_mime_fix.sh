#!/usr/bin/env bash

ls /etc/xdg/menus/
# you should see plasma-applications.menu (and maybe arch-applications-menu)

sudo ln -sf /etc/xdg/menus/plasma-applications.menu /etc/xdg/menus/applications.menu
rm ~/.cache/ksycoca6_*
kbuildsycoca6 --noincremental
