#!/usr/bin/env bash
# Idle screensaver (fullscreen mpv, no DPMS). Source from ../install.sh:
#
#   source screensaver/install.sh
#
# Or run this file directly. Does not copy the video; put it at
#   ~/Videos/screensaver/g9-screen-saver.mp4
#
# Safe to source: work runs in a subshell (no set -e leak, no exit of parent).

(
set -euo pipefail

HERE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
FILES="${HERE}/files"
QS_SCRIPTS="${HOME}/.config/quickshell/scripts"
BIN="${HOME}/.local/bin"
SHARE="${HOME}/.local/share/screensaver"
HYPR="${HOME}/.config/hypr"
CONF="${HYPR}/screensaver.conf"
HYPRIDLE="${HYPR}/hypridle.conf"
VIDEO="${HOME}/Videos/screensaver/g9-screen-saver.mp4"
PLAYER="${BIN}/screensaver.sh"
WRAPPER="${BIN}/screensaver-config.sh"

info() { printf '==> %s\n' "$*"; }
ok()   { printf '    %s\n' "$*"; }
warn() { printf 'warn: %s\n' "$*" >&2; }

# Prefer a live Quickshell tree if it already has the player + dismiss files.
src_dir() {
    if [[ -x "${QS_SCRIPTS}/screensaver.sh" \
       && -x "${QS_SCRIPTS}/screensaver-config.sh" \
       && -f "${QS_SCRIPTS}/screensaver-mpv/input.conf" \
       && -f "${QS_SCRIPTS}/screensaver-mpv/quit-on-input.lua" ]]; then
        printf '%s' "$QS_SCRIPTS"
        return 0
    fi
    printf '%s' "$FILES"
}

need_src() {
    local src="$1"
    [[ -x "${src}/screensaver.sh" ]] || { echo "error: missing ${src}/screensaver.sh" >&2; exit 1; }
    [[ -x "${src}/screensaver-config.sh" ]] || { echo "error: missing ${src}/screensaver-config.sh" >&2; exit 1; }
    [[ -f "${src}/screensaver-mpv/input.conf" ]] || { echo "error: missing ${src}/screensaver-mpv/input.conf" >&2; exit 1; }
    [[ -f "${src}/screensaver-mpv/quit-on-input.lua" ]] || { echo "error: missing ${src}/screensaver-mpv/quit-on-input.lua" >&2; exit 1; }
}

install_pkgs() {
    command -v pacman >/dev/null 2>&1 || { warn "pacman not found; install mpv hypridle python yourself"; return 0; }
    info "Installing screensaver packages (mpv, hypridle, python, ddcutil)..."
    sudo pacman -S --needed --noconfirm mpv hypridle python ddcutil
}

install_helpers() {
    local src
    src="$(src_dir)"
    need_src "$src"
    info "Installing helpers from ${src}..."
    install -d "$BIN" "$SHARE"
    install -m755 "${src}/screensaver.sh" "$PLAYER"
    install -m755 "${src}/screensaver-config.sh" "$WRAPPER"
    install -m644 "${src}/screensaver-mpv/input.conf" "${SHARE}/input.conf"
    install -m644 "${src}/screensaver-mpv/quit-on-input.lua" "${SHARE}/quit-on-input.lua"
    ok "$PLAYER"
    ok "$WRAPPER"
    ok "${SHARE}/input.conf"
    ok "${SHARE}/quit-on-input.lua"
}

write_screensaver_conf() {
    mkdir -p "$HYPR"
    if [[ -f "$CONF" ]]; then
        ok "keeping existing ${CONF}"
        return 0
    fi
    cat >"$CONF" <<EOF
# Managed by Quickshell Options → Screensaver. Do not put secrets here.
enabled=1
timeout_sec=300
video=${VIDEO}
script=${PLAYER}
ignore_inhibit=0
dim_enable=1
dim_level=10
restore_enable=1
restore_level=80
EOF
    ok "wrote ${CONF}"
}

ensure_hypridle_conf() {
    mkdir -p "$HYPR"
    if [[ -f "$HYPRIDLE" ]]; then
        return 0
    fi
    cat >"$HYPRIDLE" <<EOF
# Screensaver only. Do not DPMS the G9 (DisplayPort drop / hyprlock death).

general {
    lock_cmd = pidof hyprlock || hyprlock
    before_sleep_cmd = loginctl lock-session
    after_sleep_cmd = ~/.local/bin/wake-display.sh --after-sleep
    inhibit_sleep = 2
    ignore_dbus_inhibit = true
    ignore_systemd_inhibit = true
    ignore_wayland_inhibit = true
}
EOF
    ok "wrote ${HYPRIDLE}"
}

patch_hypridle_listener() {
    info "Patching hypridle listener..."
    # Conf already has prefs (existing or just written). Only pin the helper path.
    "$WRAPPER" set --script "$PLAYER" >/dev/null
    ok "hypridle listener → ${WRAPPER}"
}

patch_window_rule() {
    local f="${HYPR}/config/windows-and-workspaces.lua"
    [[ -f "$f" ]] || { warn "no ${f}; add a fullscreen rule for title hypr-screensaver"; return 0; }
    python3 - "$f" <<'PY'
from pathlib import Path
import sys
p = Path(sys.argv[1])
text = p.read_text()
if "hypr-screensaver" in text:
    print("    window rule already present")
    raise SystemExit(0)
block = """hl.window_rule({
    name = "screensaver-mpv",
    match = { title = "hypr-screensaver" },
    fullscreen = true,
    no_blur = true,
    opaque = true,
})

"""
marker = "-- ====================== Window Rules ======================"
if marker in text:
    i = text.find(marker) + len(marker)
    while i < len(text) and text[i] == "\n":
        i += 1
    text = text[:i] + "\n" + block + text[i:]
else:
    if text and not text.endswith("\n"):
        text += "\n"
    text += "\n" + block
p.write_text(text)
print("    added screensaver-mpv window rule")
PY
}

patch_super_l() {
    local f="${HYPR}/config/keybindings.lua"
    [[ -f "$f" ]] || { warn "no ${f}; bind Super+L to ${WRAPPER} start"; return 0; }
    python3 - "$f" <<'PY'
from pathlib import Path
import re, sys
p = Path(sys.argv[1])
text = p.read_text()
if "screensaver-config.sh start" in text:
    print("    Super+L screensaver bind already present")
    raise SystemExit(0)
bind = 'hl.bind(mainMod .. " + l", hl.dsp.exec_cmd("~/.local/bin/screensaver-config.sh start")) --#System# Start screensaver\n'
lines = text.splitlines(True)
out = []
last_l = None
for i, line in enumerate(lines):
    if re.match(r'hl\.bind\(mainMod \.\. " \+ l"', line) and "lock-screen" in line:
        line = "--" + line
    out.append(line)
    if 'mainMod .. " + l"' in line:
        last_l = len(out) - 1
if last_l is not None:
    out.insert(last_l + 1, bind)
else:
    inserted = False
    for i, line in enumerate(out):
        if "System" in line and line.lstrip().startswith("--"):
            out.insert(i + 1, bind)
            inserted = True
            break
    if not inserted:
        out.append(bind)
p.write_text("".join(out))
print("    bound Super+L to screensaver start")
PY
}

patch_autostart() {
    local f="${HYPR}/config/autostarts.lua"
    [[ -f "$f" ]] || { warn "no ${f}; start hypridle on login"; return 0; }
    python3 - "$f" <<'PY'
from pathlib import Path
import sys
p = Path(sys.argv[1])
text = p.read_text()
if 'exec_cmd("hypridle")' in text or "exec_cmd('hypridle')" in text:
    print("    hypridle autostart already present")
    raise SystemExit(0)
needle = 'hl.exec_cmd("hyprpaper")'
insert = '   hl.exec_cmd("hypridle")\n'
if needle in text:
    text = text.replace(needle, needle + "\n" + insert.rstrip("\n"), 1)
else:
    if text and not text.endswith("\n"):
        text += "\n"
    text += insert
p.write_text(text)
print("    added hypridle autostart")
PY
}

warn_video() {
    if [[ -f "$VIDEO" ]]; then
        ok "video present: ${VIDEO}"
        return 0
    fi
    warn "video not found (you said you will place it): ${VIDEO}"
}

reload_session() {
    if pgrep -x hypridle >/dev/null 2>&1; then
        pkill -HUP hypridle 2>/dev/null || true
        sleep 0.15
        if ! pgrep -x hypridle >/dev/null 2>&1; then
            hypridle >/dev/null 2>&1 &
        fi
        ok "reloaded hypridle"
    elif command -v hypridle >/dev/null 2>&1; then
        hypridle >/dev/null 2>&1 &
        ok "started hypridle"
    fi
    if [[ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]] && command -v hyprctl >/dev/null 2>&1; then
        hyprctl reload >/dev/null 2>&1 || true
        ok "hyprctl reload"
    fi
}

info "Installing Hyprland screensaver (mpv idle loop, no DPMS)..."
install_pkgs
install_helpers
write_screensaver_conf
ensure_hypridle_conf
patch_hypridle_listener
patch_window_rule
patch_super_l
patch_autostart
warn_video
reload_session
info "Screensaver install complete. Super+L starts it; mouse/click/Esc dismisses after 1s."
)
