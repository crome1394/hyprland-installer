# Screensaver installer

Idle fullscreen **mpv** (no compositor DPMS). Source this from the parent installer — do not edit `../install.sh` from here.

In `../install.sh`:

```bash
prompt_color bright "Do you want to install the screensaver? "
if [[ $answer == "y" || $answer == "Y" ]]; then
    source screensaver/install.sh
fi
```

Or run standalone:

```bash
./screensaver/install.sh
```

## What it installs

| Item | Destination |
|------|-------------|
| Player | `~/.local/bin/screensaver.sh` |
| Hypridle wrapper | `~/.local/bin/screensaver-config.sh` |
| Mouse/key dismiss | `~/.local/share/screensaver/{input.conf,quit-on-input.lua}` |
| Prefs | `~/.config/hypr/screensaver.conf` (created if missing) |
| Idle listener | patched into `~/.config/hypr/hypridle.conf` |
| Super+L | `screensaver-config.sh start` (comments an existing lock-screen bind) |
| Window rule | title `hypr-screensaver` fullscreen / no blur / opaque |
| Autostart | `hypridle` in `autostarts.lua` if that file exists |

Packages: `mpv`, `hypridle`, `python`, `ddcutil`.

Helpers are bundled under `files/`. If `~/.config/quickshell/scripts/` already has the player plus `screensaver-mpv/`, those copies are used instead.

## Video

This installer does **not** copy the clip. Place it at:

```
~/Videos/screensaver/g9-screen-saver.mp4
```

## After a reinstall

Run this script again (or `~/.config/quickshell/scripts/install-screensaver-helpers.sh` if the Quickshell tree is already cloned). Mouse dismiss must not live in `~/.config/mpv`.
