#!/usr/bin/env bash
# One-shot fix: keep SDDM greeter Plasma packages (and optional qt6ct) from being
# removed as "orphans". Safe to re-run. Requires root (run0/sudo).
set -euo pipefail

# Required for the login greeter QML modules
GREETER_PKGS=(libplasma plasma5support plasma-workspace)

# Not required by SDDM; recommended for Hyprland if you use QT_QPA_PLATFORMTHEME=qt6ct
# after greeter deps pull in plasma-integration.
COMPANION_PKGS=(qt6ct)

elevate() {
  if [[ "${EUID}" -eq 0 ]]; then
    return 0
  fi
  if command -v run0 >/dev/null 2>&1; then
    exec run0 --pty bash "$0" "$@"
  fi
  exec sudo -- "$0" "$@"
}

elevate "$@"

ALL_PKGS=("${GREETER_PKGS[@]}")
if [[ "${GENTLY_BLUR_INSTALL_QT6CT:-1}" == "1" ]]; then
  ALL_PKGS+=("${COMPANION_PKGS[@]}")
fi

echo "==> Ensuring packages are installed..."
pacman -S --needed --noconfirm "${ALL_PKGS[@]}"

echo "==> Marking them EXPLICIT (will not appear as orphans)..."
pacman -D --asexplicit "${ALL_PKGS[@]}"

echo
echo "Install reasons now:"
for p in "${ALL_PKGS[@]}"; do
  reason="$(pacman -Qi "$p" | awk -F': ' '/^Install Reason/{print $2}')"
  echo "  $p → $reason"
done

echo
echo "Done."
echo "  • Greeter packages: needed by SDDM at login (do not orphan-remove)."
echo "  • qt6ct: not needed by SDDM; keeps Dolphin/Qt theming working on Hyprland"
echo "    when QT_QPA_PLATFORMTHEME=qt6ct (skip with GENTLY_BLUR_INSTALL_QT6CT=0)."
