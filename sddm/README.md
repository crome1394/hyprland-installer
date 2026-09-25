# Gently-Blur-SDDM-6

A Plasma 6 / Qt 6 SDDM greeter theme (login screen only), with fixes for a freeze after a wrong password, optional user face image, and NumLock-on at the greeter.

This package **only affects the SDDM login screen**. It does not change Hyprland, quickshell, Wayland sessions, or other desktop configuration.

Based on the Gently-Blur SDDM theme (KDE Visual Design Group / l4k1), with local reliability fixes.

---

## Package layout

```
.
├── README.md                 # this file
├── install.sh                # automated install / uninstall
├── theme/                    # full greeter theme (copy to SDDM themes dir)
│   ├── Main.qml
│   ├── Login.qml
│   ├── metadata.desktop
│   ├── theme.conf
│   ├── background.jpg
│   ├── assets/
│   └── …
└── extras/
    ├── default-face.png      # ready-to-use 256×256 face (PNG)
    └── face-source.jpg       # original source photo
```

---

## Requirements

| Component | Notes |
|-----------|--------|
| **SDDM** | Qt 6 greeter (`sddm-greeter-qt6`) |
| **Display manager** | SDDM enabled (e.g. `systemctl enable sddm`) |
| **Plasma QML modules** | This theme imports Breeze/Plasma components (see below) |

### Runtime packages (Arch / CachyOS / pacman)

**Install them as explicit packages** (not as orphans/deps). The greeter needs them at boot, but nothing in your logged-in Hyprland session may “require” them — so orphan removers will delete `plasma5support` and break the theme if they were only `--asdeps`.

```bash
sudo pacman -S --needed libplasma plasma5support plasma-workspace
sudo pacman -D --asexplicit libplasma plasma5support plasma-workspace
```

Or from this package:

```bash
./fix-greeter-deps.sh
```

These pull in the QML modules the greeter needs:

- `org.kde.plasma.components`
- `org.kde.plasma.plasma5support`
- `org.kde.plasma.extras`
- `org.kde.breeze.components`
- `org.kde.kirigami`

On other distros, install the equivalent Plasma 6 workspace / libplasma packages.

Optional but useful:

- `imagemagick` — only if you resize/convert a custom face yourself  
- `qt6-svg`, `qt6-5compat` — usually already present with the deps above  

---

## Automated install

From this directory:

```bash
chmod +x install.sh
./install.sh              # same as: ./install.sh install
```

The script will:

1. Elevate with `run0` (polkit) or `sudo`
2. Install greeter dependencies via `pacman` as `--asdeps` (Arch-based)
3. Copy `theme/` → `/usr/share/sddm/themes/Gently-Blur-SDDM-6`
4. Write `/etc/sddm.conf.d/99-gently-blur.conf` (theme + NumLock)
5. Install the bundled face for the invoking user
6. Record state under `/var/lib/gently-blur-sddm/` for clean uninstall

### Options (environment)

| Variable | Default | Meaning |
|----------|---------|---------|
| `GENTLY_BLUR_INSTALL_DEPS` | `1` | Install greeter Plasma packages (explicit) |
| `GENTLY_BLUR_INSTALL_QT6CT` | `1` | Also install `qt6ct` (Hyprland Qt theming companion) |
| `GENTLY_BLUR_INSTALL_FACE` | `1` | Install bundled face for your user |
| `GENTLY_BLUR_INSTALL_NUMLOCK` | `1` | Set `Numlock=on` at the greeter |

Examples:

```bash
# Theme + deps only (no face, no NumLock)
GENTLY_BLUR_INSTALL_FACE=0 GENTLY_BLUR_INSTALL_NUMLOCK=0 ./install.sh

# Theme only (you already installed Plasma packages)
GENTLY_BLUR_INSTALL_DEPS=0 ./install.sh

# Skip qt6ct (greeter-only machine, or you use a different Qt theme stack)
GENTLY_BLUR_INSTALL_QT6CT=0 ./install.sh
```

### Automated uninstall (restore SDDM default greeter)

```bash
./install.sh uninstall
```

This removes:

- `/usr/share/sddm/themes/Gently-Blur-SDDM-6`
- `/etc/sddm.conf.d/99-gently-blur.conf`
- Face files the installer recorded for your user
- Greeter-only packages it installed as deps (when nothing else needs them)

It does **not** edit `/etc/sddm.conf` (e.g. your `Session=hyprland` Autologin entry stays intact).

Log out or reboot after install or uninstall.

---

## Manual install

Use this if you prefer not to run `install.sh`, or you are on a non-pacman system.

### 1. Install dependencies

**Arch / CachyOS:**

```bash
sudo pacman -S --needed --asdeps libplasma plasma5support plasma-workspace
```

**Other distros:** install Plasma 6 packages that provide the QML modules listed under [Requirements](#requirements).

### 2. Install the theme files

```bash
sudo cp -a theme /usr/share/sddm/themes/Gently-Blur-SDDM-6
sudo chmod -R a+rX /usr/share/sddm/themes/Gently-Blur-SDDM-6
```

The greeter runs as the `sddm` user, so the tree must be world-readable.

### 3. Select the theme (and optional NumLock)

Create a drop-in config (recommended — leaves `/etc/sddm.conf` alone):

```bash
sudo tee /etc/sddm.conf.d/99-gently-blur.conf >/dev/null <<'EOF'
[Theme]
Current=Gently-Blur-SDDM-6

[General]
Numlock=on
EOF
```

If you only want the theme and **not** NumLock:

```bash
sudo tee /etc/sddm.conf.d/99-gently-blur.conf >/dev/null <<'EOF'
[Theme]
Current=Gently-Blur-SDDM-6
EOF
```

Alternatively, edit `/etc/sddm.conf` (or your existing drop-ins) and set:

```ini
[Theme]
Current=Gently-Blur-SDDM-6

[General]
Numlock=on
```

### 4. (Optional) Set your user face / avatar

SDDM loads faces from `/usr/share/sddm/faces/<username>.face.icon` (and often `~/.face.icon`).

Replace `YOURUSER` with your login name:

```bash
# Using the bundled 256×256 PNG (recommended)
sudo cp extras/default-face.png /usr/share/sddm/faces/YOURUSER.face.icon
sudo chmod 644 /usr/share/sddm/faces/YOURUSER.face.icon

cp extras/default-face.png ~/.face.icon
chmod 644 ~/.face.icon
ln -sfn .face.icon ~/.face
```

Or resize the original photo with ImageMagick:

```bash
magick extras/face-source.jpg -resize '256x256^' -gravity center -extent 256x256 \
  png:/tmp/face.png
sudo cp /tmp/face.png /usr/share/sddm/faces/YOURUSER.face.icon
cp /tmp/face.png ~/.face.icon
```

### 5. Apply

```bash
# optional: confirm theme is visible to SDDM
ls /usr/share/sddm/themes/Gently-Blur-SDDM-6/Main.qml

# log out, or:
# systemctl restart sddm   # caution: closes the graphical session
```

Log out (or reboot) to see the greeter.

### Manual preview (optional)

If you are already in a graphical session and have a working X/Wayland display for the greeter test mode:

```bash
sddm-greeter-qt6 --test-mode --theme /usr/share/sddm/themes/Gently-Blur-SDDM-6
```

---

## Manual uninstall (restore default greeter)

```bash
# 1. Remove theme
sudo rm -rf /usr/share/sddm/themes/Gently-Blur-SDDM-6

# 2. Remove drop-in (restores default theme selection)
sudo rm -f /etc/sddm.conf.d/99-gently-blur.conf

# 3. If you set Current= in /etc/sddm.conf by hand, clear or delete that line:
#    [Theme]
#    Current=

# 4. Optional: remove your face files
sudo rm -f /usr/share/sddm/faces/YOURUSER.face.icon
rm -f ~/.face.icon ~/.face

# 5. Optional (Arch): remove greeter deps if nothing else needs them
sudo pacman -Rns libplasma plasma5support plasma-workspace
# If pacman refuses, other packages still depend on them — that is fine.
```

Log out or reboot.

---

## Side effects on Hyprland / Dolphin (Qt theming)

Installing Plasma greeter libraries also installs `plasma-integration` (KDE Qt platform theme). That can change how Dolphin and other Qt apps look **even though you do not run Plasma**.

If you see light grey bars / mixed light-dark chrome in Dolphin (Breeze Dark):

1. Ensure `~/.config/kdeglobals` sets dark Breeze:
   ```ini
   [General]
   ColorScheme=BreezeDark
   [KDE]
   widgetStyle=Breeze
   [Icons]
   Theme=breeze-dark
   ```
2. Point Qt at a real platform theme. If `QT_QPA_PLATFORMTHEME=qt6ct` but `qt6ct` is not installed, Qt falls into a broken hybrid.
   - The installer installs `qt6ct` by default (`GENTLY_BLUR_INSTALL_QT6CT=1`) for this reason.
   - Or use `QT_QPA_PLATFORMTHEME=kde` with BreezeDark in `kdeglobals`.
3. Restart Dolphin (or re-login) after changing env / `kdeglobals`.

### Should qt6ct be a dependency?

| | |
|--|--|
| **Required for SDDM login theme?** | **No.** The greeter does not use qt6ct. |
| **Recommended on Hyprland?** | **Yes**, if you use Dolphin/other Qt apps and `QT_QPA_PLATFORMTHEME=qt6ct`. Greeter deps pull in `plasma-integration`; without qt6ct you can get broken light/dark chrome (e.g. grey bars in Dolphin). |
| **Installer default** | Install qt6ct as an **explicit companion** package. Disable with `GENTLY_BLUR_INSTALL_QT6CT=0`. |

---

## What this does *not* change

- Hyprland / quickshell / window manager config  
- Your desktop wallpaper, locks screen, or shell  
- `/etc/sddm.conf` entries other tools manage (e.g. `[Autologin] Session=hyprland`), when using the drop-in method  

---

## Updates and system upgrades

| What updates | Effect on this theme |
|--------------|----------------------|
| **SDDM package** (`pacman -Syu sddm`) | Safe. Theme is not a distro package file; config is a drop-in under `/etc/sddm.conf.d/` that package managers do not overwrite. |
| **Plasma packages** (`plasma-workspace`, `libplasma`, …) | Usually fine. The greeter **imports** shared QML modules from Plasma. A major Plasma redesign *could* break the greeter until you update the theme files. Re-run `./install.sh` after pulling a fixed `theme/`. |
| **This package** (re-run `./install.sh`) | Safe and idempotent: replaces the theme directory, rewrites only `99-gently-blur.conf`, refreshes the face if enabled. |
| **Uninstall** | Restores the default greeter; does not touch `/etc/sddm.conf` session/autologin settings. Only removes packages **this installer newly added**. |

The installer never patches SDDM or Plasma themselves — it only adds a theme directory and a small config drop-in.

---

## Troubleshooting

| Symptom | What to try |
|---------|-------------|
| Black / empty greeter | Install Plasma deps (`libplasma`, `plasma5support`, `plasma-workspace`). Check `journalctl -u sddm -b` and greeter lines for QML import errors. |
| Wrong password freezes UI | Ensure you are using this package’s `Login.qml` / `Main.qml` (includes the freeze fix + 8s watchdog). |
| Default avatar instead of photo | Confirm `/usr/share/sddm/faces/$USER.face.icon` exists, is readable, and is PNG/JPEG data. Filename must be `username.face.icon`. |
| NumLock still off | Confirm `[General] Numlock=on` in a file under `/etc/sddm.conf.d/` or `/etc/sddm.conf`. Note: ignored if full autologin (User+Session) skips the greeter. |
| Theme not selected | `Current=` must match the directory name: `Gently-Blur-SDDM-6`. |

Useful logs:

```bash
journalctl -u sddm -b --no-pager | tail -80
```

---

## License

Theme derivation follows the upstream theme license (**CC-BY-SA** per `theme/metadata.desktop`).  
Installer scripts and packaging in this directory: use and modify freely with the theme.
