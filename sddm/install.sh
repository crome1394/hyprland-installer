#!/usr/bin/env bash
# Gently-Blur-SDDM-6 installer / uninstaller
# Installs only the SDDM login greeter theme (does not change your desktop session).
#
# Run this file (bash sddm/install.sh). Do not source it: elevate() re-execs
# the script as root, and a sourced $0 is the parent installer.

# If someone `source`s us, run as a child so we do not replace the parent.
if [[ "${BASH_SOURCE[0]}" != "$0" ]]; then
  bash "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/$(basename -- "${BASH_SOURCE[0]}")" "$@"
  return $?
fi

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
SELF="${SCRIPT_DIR}/$(basename -- "${BASH_SOURCE[0]}")"
THEME_SRC="${SCRIPT_DIR}/theme"
EXTRAS_SRC="${SCRIPT_DIR}/extras"
THEME_NAME="Gently-Blur-SDDM-6"
THEME_DST="/usr/share/sddm/themes/${THEME_NAME}"
SDDM_DROPIN_DIR="/etc/sddm.conf.d"
# Single drop-in we own — uninstall removes only this file (+ known legacy names)
DROPIN_FILE="${SDDM_DROPIN_DIR}/99-gently-blur.conf"
# Drop-ins created by earlier manual setup of this same theme (safe to remove)
LEGACY_DROPINS=(
  "${SDDM_DROPIN_DIR}/theme.conf"
  "${SDDM_DROPIN_DIR}/numlock.conf"
)
STATE_DIR="/var/lib/gently-blur-sddm"
STATE_FILE="${STATE_DIR}/install-state"

# Packages required by this Plasma-6-based greeter theme (Arch / CachyOS / pacman).
# Installed as EXPLICIT (not --asdeps) so CachyOS / "Remove orphans" will not
# delete plasma5support and break the greeter after the next cleanup.
PACMAN_DEPS=(libplasma plasma5support plasma-workspace)

# Not required by SDDM itself — recommended for Hyprland/Qt apps after greeter
# deps pull in plasma-integration (avoids broken theming if QT_QPA_PLATFORMTHEME=qt6ct).
PACMAN_SESSION_COMPANIONS=(qt6ct)

# ---------- helpers ----------

die()  { echo "error: $*" >&2; exit 1; }
info() { echo "==> $*"; }
ok()   { echo "    $*"; }

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "required command not found: $1"
}

is_root() { [[ "${EUID:-$(id -u)}" -eq 0 ]]; }

# Re-exec as root via run0 (polkit) or sudo
elevate() {
  if is_root; then
    return 0
  fi
  # Preserve the real user for face install
  export GENTLY_BLUR_INVOKING_USER="${SUDO_USER:-${USER:-$(id -un)}}"
  local -a env_pass=(
    --setenv=GENTLY_BLUR_INVOKING_USER="${GENTLY_BLUR_INVOKING_USER}"
    --setenv=GENTLY_BLUR_INSTALL_FACE="${GENTLY_BLUR_INSTALL_FACE:-1}"
    --setenv=GENTLY_BLUR_INSTALL_NUMLOCK="${GENTLY_BLUR_INSTALL_NUMLOCK:-1}"
    --setenv=GENTLY_BLUR_INSTALL_DEPS="${GENTLY_BLUR_INSTALL_DEPS:-1}"
    --setenv=GENTLY_BLUR_INSTALL_QT6CT="${GENTLY_BLUR_INSTALL_QT6CT:-1}"
  )
  if command -v run0 >/dev/null 2>&1; then
    info "Elevating privileges with run0 (polkit)..."
    exec run0 --pty "${env_pass[@]}" bash "$SELF" "$@"
  elif command -v sudo >/dev/null 2>&1; then
    info "Elevating privileges with sudo..."
    exec sudo --preserve-env=GENTLY_BLUR_INVOKING_USER,GENTLY_BLUR_INSTALL_FACE,GENTLY_BLUR_INSTALL_NUMLOCK,GENTLY_BLUR_INSTALL_DEPS,GENTLY_BLUR_INSTALL_QT6CT \
      -- "$SELF" "$@"
  else
    die "need root (install run0/sudo, or re-run as root)"
  fi
}

detect_target_user() {
  local u="${GENTLY_BLUR_INVOKING_USER:-${SUDO_USER:-}}"
  if [[ -z "$u" || "$u" == "root" ]]; then
    u="$(logname 2>/dev/null || true)"
  fi
  if [[ -z "$u" || "$u" == "root" ]]; then
    u="$(awk -F: '$3>=1000 && $3<65534 {print $1; exit}' /etc/passwd || true)"
  fi
  printf '%s' "$u"
}

user_home() {
  getent passwd "$1" | awk -F: '{print $6}'
}

pkg_manager() {
  if command -v pacman >/dev/null 2>&1; then
    echo pacman
  else
    echo none
  fi
}

# Read key=value state without `source` (avoids code execution from a tainted file)
state_get() {
  # usage: state_get <file> <key>
  local file="$1" key="$2" line
  [[ -f "$file" ]] || return 0
  [[ "$key" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]] || return 0
  line="$(grep -E "^${key}=" "$file" 2>/dev/null | head -n1 || true)"
  [[ -n "$line" ]] || return 0
  printf '%s' "${line#*=}"
}

# True if a drop-in looks like it only configures this theme / our numlock
is_our_legacy_dropin() {
  local f="$1"
  [[ -f "$f" ]] || return 1
  # Must mention our theme name OR only Numlock=on with [General] (numlock.conf)
  if grep -q "Gently-Blur-SDDM-6\|Current=Gently-Blur" "$f" 2>/dev/null; then
    return 0
  fi
  # numlock-only drop-in we created earlier: exactly Numlock under General
  if grep -q '^Numlock=on' "$f" 2>/dev/null \
     && ! grep -qE '^(User|Session|DisplayServer|Current)=' "$f" 2>/dev/null; then
    # Only treat as ours if the basename is the known legacy name
    [[ "$(basename "$f")" == "numlock.conf" ]]
    return
  fi
  return 1
}

remove_legacy_dropins() {
  local f
  for f in "${LEGACY_DROPINS[@]}"; do
    if is_our_legacy_dropin "$f"; then
      rm -f "$f"
      ok "removed legacy drop-in ${f}"
    fi
  done
}

install_deps_pacman() {
  if [[ "${GENTLY_BLUR_INSTALL_DEPS:-1}" != "1" ]]; then
    info "Skipping package dependencies (GENTLY_BLUR_INSTALL_DEPS=0)"
    return 0
  fi

  info "Installing greeter runtime dependencies (explicit — not orphans)..."

  # Record packages NOT installed before we touch the system, so uninstall
  # only removes what this installer introduced (not pre-existing packages).
  local -a newly=()
  local p
  for p in "${PACMAN_DEPS[@]}"; do
    if ! pacman -Q "$p" &>/dev/null; then
      newly+=("$p")
    fi
  done

  # Do NOT use --asdeps. The greeter needs these at boot; if they are marked
  # as dependencies with no reverse deps (especially plasma5support), tools
  # like CachyOS "remove orphans" will delete them and break the login theme.
  pacman -S --needed --noconfirm "${PACMAN_DEPS[@]}"

  # Force-explicit even if a prior install left them as deps
  pacman -D --asexplicit "${PACMAN_DEPS[@]}"
  ok "marked explicit: ${PACMAN_DEPS[*]}"

  # Session companion: qt6ct (Hyprland Qt theming). Not needed by SDDM greeter.
  if [[ "${GENTLY_BLUR_INSTALL_QT6CT:-1}" == "1" ]]; then
    local -a companions_new=()
    for p in "${PACMAN_SESSION_COMPANIONS[@]}"; do
      if ! pacman -Q "$p" &>/dev/null; then
        companions_new+=("$p")
      fi
    done
    info "Installing session companion packages (qt6ct for post-login Qt apps)..."
    pacman -S --needed --noconfirm "${PACMAN_SESSION_COMPANIONS[@]}"
    pacman -D --asexplicit "${PACMAN_SESSION_COMPANIONS[@]}"
    ok "marked explicit: ${PACMAN_SESSION_COMPANIONS[*]}"
    newly+=("${companions_new[@]}")
  else
    info "Skipping qt6ct (GENTLY_BLUR_INSTALL_QT6CT=0)"
  fi

  if ((${#newly[@]} > 0)); then
    printf '%s\n' "${newly[@]}" > "${STATE_DIR}/pacman-owned.txt"
    ok "recorded new packages for uninstall: ${newly[*]}"
  else
    : > "${STATE_DIR}/pacman-owned.txt"
    ok "all greeter deps were already present (still marked explicit)"
  fi
  # Keep legacy filename empty so old uninstall paths do not remove too much
  : > "${STATE_DIR}/pacman-asdeps.txt"
  ok "dependencies ready"
}

remove_deps_pacman() {
  local list="${STATE_DIR}/pacman-owned.txt"
  [[ -f "$list" ]] || list="${STATE_DIR}/pacman-asdeps.txt"
  if [[ ! -f "$list" ]]; then
    info "No recorded package deps to remove (safe: leaving system packages alone)"
    info "If you want to drop greeter packages manually later:"
    info "  pacman -Rns libplasma plasma5support plasma-workspace"
    return 0
  fi
  mapfile -t pkgs < <(grep -E '^[a-zA-Z0-9@._+-]+$' "$list" || true)
  if ((${#pkgs[@]} == 0)); then
    info "No package deps recorded for removal (they were already on the system)."
    info "Left explicit greeter packages installed. Remove manually if desired:"
    info "  pacman -Rns libplasma plasma5support plasma-workspace"
    return 0
  fi
  info "Attempting to remove packages this installer added (${pkgs[*]})..."
  # -Rns fails safely if something else still needs them
  if pacman -Rns --noconfirm "${pkgs[@]}" 2>/dev/null; then
    ok "removed: ${pkgs[*]}"
  else
    info "Kept some packages (still required by other software). That is fine."
  fi
}

write_dropin() {
  mkdir -p "${SDDM_DROPIN_DIR}"
  # Collapse any earlier split drop-ins into the single managed file
  remove_legacy_dropins

  {
    echo "# Managed by Gently-Blur-SDDM-6 install.sh — remove via: ./install.sh uninstall"
    echo "# Safe across SDDM package upgrades (lives in /etc/sddm.conf.d, not overwritten)."
    echo "[Theme]"
    echo "Current=${THEME_NAME}"
    if [[ "${GENTLY_BLUR_INSTALL_NUMLOCK:-1}" == "1" ]]; then
      echo
      echo "[General]"
      echo "Numlock=on"
    fi
  } > "${DROPIN_FILE}"
  ok "wrote ${DROPIN_FILE}"
}

install_theme_files() {
  [[ -f "${THEME_SRC}/Main.qml" && -f "${THEME_SRC}/metadata.desktop" ]] \
    || die "theme sources missing under ${THEME_SRC}"

  info "Installing theme to ${THEME_DST}..."
  # Replace in place: theme is not owned by a distro package, so upgrades
  # never touch it. Re-install is idempotent.
  rm -rf "${THEME_DST}"
  mkdir -p "${THEME_DST}"
  cp -a "${THEME_SRC}/." "${THEME_DST}/"
  # Greeter runs as user "sddm" — world-readable is required
  chmod -R a+rX "${THEME_DST}"
  # Ensure we did not copy a backup with wrong owner that sddm cannot read
  find "${THEME_DST}" -type d -exec chmod a+rx {} +
  find "${THEME_DST}" -type f -exec chmod a+r {} +
  ok "theme installed"
}

install_face_for_user() {
  if [[ "${GENTLY_BLUR_INSTALL_FACE:-1}" != "1" ]]; then
    info "Skipping user face (GENTLY_BLUR_INSTALL_FACE=0)"
    return 0
  fi

  local user home face_src face_dst_sddm face_dst_home tmp_face
  user="$(detect_target_user)"
  [[ -n "$user" ]] || { info "No target user for face; skipping"; return 0; }
  # Reject weird usernames before path construction
  [[ "$user" =~ ^[a-z_][a-z0-9_-]*$ ]] || die "refusing unsafe username for face install: ${user}"

  home="$(user_home "$user")"
  [[ -n "$home" && -d "$home" ]] || { info "Home for ${user} not found; skipping face"; return 0; }

  if [[ -f "${EXTRAS_SRC}/default-face.png" ]]; then
    face_src="${EXTRAS_SRC}/default-face.png"
  elif [[ -f "${EXTRAS_SRC}/face-source.jpg" ]]; then
    face_src="${EXTRAS_SRC}/face-source.jpg"
  else
    info "No face image bundled; skipping"
    return 0
  fi

  face_dst_sddm="/usr/share/sddm/faces/${user}.face.icon"
  face_dst_home="${home}/.face.icon"

  info "Installing login face for user '${user}'..."
  mkdir -p /usr/share/sddm/faces

  # Convert once, reuse for all destinations (efficient + consistent)
  tmp_face="$(mktemp /tmp/gently-blur-face.XXXXXX.png)"
  cleanup_tmp() { rm -f "${tmp_face}"; }
  trap cleanup_tmp RETURN

  if command -v magick >/dev/null 2>&1; then
    magick "${face_src}" -resize '256x256^' -gravity center -extent 256x256 "png:${tmp_face}"
  else
    cp -f "${face_src}" "${tmp_face}"
  fi

  install -m 644 "${tmp_face}" "${face_dst_sddm}"
  install -m 644 -o "${user}" -g "${user}" "${tmp_face}" "${face_dst_home}" 2>/dev/null \
    || { cp -f "${tmp_face}" "${face_dst_home}"; chown "${user}:${user}" "${face_dst_home}" 2>/dev/null || true; chmod 644 "${face_dst_home}"; }
  ln -sfn .face.icon "${home}/.face" 2>/dev/null || true

  # AccountsService (optional)
  if [[ -d /var/lib/AccountsService ]]; then
    mkdir -p /var/lib/AccountsService/icons
    install -m 644 "${tmp_face}" "/var/lib/AccountsService/icons/${user}"
    mkdir -p /var/lib/AccountsService/users
    local as_user="/var/lib/AccountsService/users/${user}"
    if [[ ! -f "${as_user}" ]]; then
      cat > "${as_user}" <<EOF
[User]
Icon=/var/lib/AccountsService/icons/${user}
SystemAccount=false
EOF
    elif grep -q '^Icon=' "${as_user}" 2>/dev/null; then
      # in-place replace only the Icon line; keep the rest of the file
      sed -i "s|^Icon=.*|Icon=/var/lib/AccountsService/icons/${user}|" "${as_user}"
    else
      printf '\nIcon=/var/lib/AccountsService/icons/%s\n' "${user}" >> "${as_user}"
    fi
  fi

  # Record for uninstall (plain key=value, never sourced as shell)
  {
    echo "user=${user}"
    echo "sddm_face=${face_dst_sddm}"
    echo "home_face=${face_dst_home}"
    echo "accounts_icon=/var/lib/AccountsService/icons/${user}"
  } > "${STATE_DIR}/face.txt"

  ok "face installed for ${user}"
}

write_state() {
  mkdir -p "${STATE_DIR}"
  cat > "${STATE_FILE}" <<EOF
theme_name=${THEME_NAME}
theme_dst=${THEME_DST}
dropin=${DROPIN_FILE}
installed_at=$(date -Is)
installer_version=2
EOF
}

do_install() {
  elevate install "$@"

  need_cmd cp
  mkdir -p "${STATE_DIR}"

  case "$(pkg_manager)" in
    pacman) install_deps_pacman ;;
    *)
      info "Non-pacman system: install Qt6/Plasma greeter deps yourself if the theme fails to load."
      info "Needed QML modules: org.kde.plasma.components, plasma5support, org.kde.breeze.components, kirigami"
      ;;
  esac

  install_theme_files
  write_dropin
  install_face_for_user
  write_state

  echo
  info "Install complete."
  ok "Theme:  ${THEME_DST}"
  ok "Config: ${DROPIN_FILE}"
  ok "Your existing /etc/sddm.conf was not modified."
  echo
  echo "Log out or reboot to see the new login screen."
  echo "Uninstall / restore defaults:  $0 uninstall"
}

remove_face_from_state() {
  local face_file="${STATE_DIR}/face.txt"
  [[ -f "$face_file" ]] || return 0

  local sddm_face home_face accounts_icon hdir
  sddm_face="$(state_get "$face_file" sddm_face)"
  home_face="$(state_get "$face_file" home_face)"
  accounts_icon="$(state_get "$face_file" accounts_icon)"

  if [[ -n "${sddm_face}" && "${sddm_face}" == /usr/share/sddm/faces/*.face.icon && -f "${sddm_face}" ]]; then
    rm -f "${sddm_face}"
    ok "removed ${sddm_face}"
  fi
  if [[ -n "${home_face}" && "${home_face}" == */.face.icon && -f "${home_face}" ]]; then
    rm -f "${home_face}"
    hdir="$(dirname "${home_face}")"
    if [[ -L "${hdir}/.face" ]]; then
      rm -f "${hdir}/.face"
    fi
    ok "removed ${home_face}"
  fi
  if [[ -n "${accounts_icon}" && "${accounts_icon}" == /var/lib/AccountsService/icons/* && -f "${accounts_icon}" ]]; then
    rm -f "${accounts_icon}"
    ok "removed ${accounts_icon}"
  fi
}

do_uninstall() {
  elevate uninstall "$@"

  info "Restoring SDDM greeter defaults (removing Gently-Blur only)..."

  if [[ -d "${THEME_DST}" ]]; then
    rm -rf "${THEME_DST}"
    ok "removed ${THEME_DST}"
  else
    ok "theme directory already absent"
  fi

  if [[ -f "${DROPIN_FILE}" ]]; then
    rm -f "${DROPIN_FILE}"
    ok "removed ${DROPIN_FILE}"
  else
    ok "drop-in already absent"
  fi
  remove_legacy_dropins

  remove_face_from_state

  case "$(pkg_manager)" in
    pacman) remove_deps_pacman ;;
  esac

  rm -rf "${STATE_DIR}"

  echo
  info "Uninstall complete. SDDM will use its default greeter theme."
  ok "Session settings in /etc/sddm.conf (e.g. Hyprland Autologin Session=) were left unchanged."
  echo "Log out or reboot to apply."
}

usage() {
  cat <<EOF
Gently-Blur-SDDM-6 installer

Usage:
  $0 [install]     Install theme, optional face, NumLock-on, and runtime deps
  $0 uninstall     Remove theme and restore SDDM default greeter
  $0 help          Show this help

Environment flags (set to 0 to disable):
  GENTLY_BLUR_INSTALL_DEPS=1      Install Plasma QML packages (explicit)
  GENTLY_BLUR_INSTALL_QT6CT=1     Also install qt6ct (Hyprland Qt theming companion)
  GENTLY_BLUR_INSTALL_FACE=1      Install bundled face for the invoking user
  GENTLY_BLUR_INSTALL_NUMLOCK=1   Turn NumLock on at the login screen

Examples:
  ./install.sh
  ./install.sh uninstall
  GENTLY_BLUR_INSTALL_FACE=0 ./install.sh install
  GENTLY_BLUR_INSTALL_QT6CT=0 ./install.sh install   # greeter only, no qt6ct

Notes:
  • Greeter theme affects the SDDM login screen only.
  • Requires root (via run0/polkit or sudo).
  • Theme lives under /usr/share/sddm/themes/ (not a pacman package), so system
    upgrades will not overwrite or remove it.
  • Config is a dedicated drop-in under /etc/sddm.conf.d/ (not /etc/sddm.conf).
  • Greeter packages are installed as EXPLICIT so orphan-cleanup tools will not
    delete plasma5support / friends and break the login screen.
  • qt6ct is optional for SDDM but recommended on Hyprland when greeter deps
    pull plasma-integration and you use QT_QPA_PLATFORMTHEME=qt6ct.
  • On uninstall, only packages this installer newly added are removed (and only
    if nothing else still needs them).
EOF
}

# ---------- main ----------
cmd="${1:-install}"
case "$cmd" in
  install)        shift || true; do_install "$@" ;;
  uninstall|remove|restore)
                  shift || true; do_uninstall "$@" ;;
  help|-h|--help) usage ;;
  *)              die "unknown command: $cmd (try: install | uninstall | help)" ;;
esac
