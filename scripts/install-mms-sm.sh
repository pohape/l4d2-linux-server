#!/usr/bin/env bash
#
# Step 5: install Metamod:Source and SourceMod into the L4D2 game directory.
#
# Pins the Linux 1.12 builds verified in a real deployment. If these exact
# URLs ever get retired by AlliedModders, update them in this file.
#
# Idempotent — if Metamod/SourceMod are already installed, skips the
# download. To reinstall, remove addons/metamod.vdf and addons/sourcemod/
# first, then re-run.

set -euo pipefail
source "$(cd "$(dirname "$0")" && pwd)/_common.sh"

MMS_URL="https://mms.alliedmods.net/mmsdrop/1.12/mmsource-1.12.0-git1219-linux.tar.gz"
SM_URL="https://sm.alliedmods.net/smdrop/1.12/sourcemod-1.12.0-git7223-linux.tar.gz"

require_root "$@"
require_user "$STEAM_USER"

if ! sudo -u "$STEAM_USER" test -d "$GAME_DIR"; then
  err "Game directory $GAME_DIR does not exist. Install L4D2 via SteamCMD first."
  exit 1
fi

if sudo -u "$STEAM_USER" test -f "$GAME_DIR/addons/metamod.vdf" \
   && sudo -u "$STEAM_USER" test -d "$GAME_DIR/addons/metamod"; then
  skip "Metamod already installed (remove addons/metamod.vdf to reinstall)"
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

if sudo -u "$STEAM_USER" test -d "$GAME_DIR/addons/sourcemod/plugins"; then
  skip "SourceMod already installed (remove addons/sourcemod/ to reinstall)"
else
  info "Installing SourceMod from $SM_URL"
  sudo -u "$STEAM_USER" -H bash -c "
    set -euo pipefail
    curl -fsSL '$SM_URL' -o /tmp/sourcemod.tar.gz
    tar -xzf /tmp/sourcemod.tar.gz -C '$GAME_DIR'
    rm -f /tmp/sourcemod.tar.gz
  "
  # SM ships admins_simple.ini with only doc comments, no actual "Admins" {}
  # block. Removing it here so install-templates.sh places our version that
  # contains the wrapper and a commented example.
  sudo -u "$STEAM_USER" rm -f "$GAME_DIR/addons/sourcemod/configs/admins_simple.ini"
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
