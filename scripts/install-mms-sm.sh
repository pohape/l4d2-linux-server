#!/usr/bin/env bash
#
# Step 5: install Metamod:Source and SourceMod into the L4D2 game directory.
#
# Idempotent: if Metamod/SourceMod are already installed, skips the download.
# Set FORCE=1 to reinstall (overwrites matching files; local edits to files
# not shipped in the archives are preserved).
#
# URLs pin the 1.12 branch that was verified in a real deployment.
# If AlliedModders retires these exact builds, override via env:
#   MMS_URL=... SM_URL=... sudo -E bash install-mms-sm.sh

set -euo pipefail
source "$(cd "$(dirname "$0")" && pwd)/_common.sh"

MMS_URL="${MMS_URL:-https://mms.alliedmods.net/mmsdrop/1.12/mmsource-1.12.0-git1219-linux.tar.gz}"
SM_URL="${SM_URL:-https://sm.alliedmods.net/smdrop/1.12/sourcemod-1.12.0-git7223-linux.tar.gz}"
FORCE="${FORCE:-0}"

require_root "$@"
require_user "$STEAM_USER"

if ! sudo -u "$STEAM_USER" test -d "$GAME_DIR"; then
  err "Game directory $GAME_DIR does not exist. Install L4D2 via SteamCMD first."
  exit 1
fi

mms_installed=0
if sudo -u "$STEAM_USER" test -f "$GAME_DIR/addons/metamod.vdf" \
   && sudo -u "$STEAM_USER" test -d "$GAME_DIR/addons/metamod"; then
  mms_installed=1
fi

sm_installed=0
if sudo -u "$STEAM_USER" test -d "$GAME_DIR/addons/sourcemod/plugins"; then
  sm_installed=1
fi

if [ "$mms_installed" = "1" ] && [ "$FORCE" != "1" ]; then
  skip "Metamod already installed (set FORCE=1 to reinstall)"
else
  info "Installing Metamod:Source from $MMS_URL"
  sudo -u "$STEAM_USER" -H bash -c "
    set -euo pipefail
    curl -fsSL '$MMS_URL' -o /tmp/mmsource.tar.gz
    tar -xzf /tmp/mmsource.tar.gz -C '$GAME_DIR'
    rm -f /tmp/mmsource.tar.gz
  "
  ok "Metamod installed"
fi

if [ "$sm_installed" = "1" ] && [ "$FORCE" != "1" ]; then
  skip "SourceMod already installed (set FORCE=1 to reinstall)"
else
  info "Installing SourceMod from $SM_URL"
  sudo -u "$STEAM_USER" -H bash -c "
    set -euo pipefail
    curl -fsSL '$SM_URL' -o /tmp/sourcemod.tar.gz
    tar -xzf /tmp/sourcemod.tar.gz -C '$GAME_DIR'
    rm -f /tmp/sourcemod.tar.gz
  "
  ok "SourceMod installed"
fi

info "Disabling nextmap.smx (forced map rotation) if present"
DISABLED_DIR="$GAME_DIR/addons/sourcemod/plugins/disabled"
NEXTMAP="$GAME_DIR/addons/sourcemod/plugins/nextmap.smx"

sudo -u "$STEAM_USER" mkdir -p "$DISABLED_DIR"
if sudo -u "$STEAM_USER" test -f "$NEXTMAP"; then
  sudo -u "$STEAM_USER" mv "$NEXTMAP" "$DISABLED_DIR/"
  ok "Moved nextmap.smx to $DISABLED_DIR/"
else
  skip "nextmap.smx not in active plugins"
fi
