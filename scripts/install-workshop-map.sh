#!/usr/bin/env bash
#
# Install an L4D2 Steam Workshop VPK (map or addon) into the server.
#
# Usage:
#   sudo install-workshop-map.sh <WORKSHOP_ITEM> [VPK_NAME]
#
# Downloads the workshop item via anonymous SteamCMD and copies the result
# into addons/ as a .vpk.
#
# Arguments:
#   WORKSHOP_ITEM  workshop file id, e.g. 1432537029
#   VPK_NAME       destination filename (default: workshop_<WORKSHOP_ITEM>.vpk)
#
# Idempotent — skips the download if the target VPK already exists.
# To re-download, delete the file first, then run the script again.

set -euo pipefail
source "$(cd "$(dirname "$0")" && pwd)/_common.sh"

WORKSHOP_ITEM="${1:-}"
VPK_NAME="${2:-}"

if [ -z "$WORKSHOP_ITEM" ]; then
  err "WORKSHOP_ITEM is required."
  err "Usage: sudo $0 <WORKSHOP_ITEM> [VPK_NAME]"
  err "Example: sudo $0 1432537029"
  exit 2
fi

if [ -z "$VPK_NAME" ]; then
  VPK_NAME="workshop_${WORKSHOP_ITEM}.vpk"
fi

require_root "$@"
require_user "$STEAM_USER"

TARGET="$GAME_DIR/addons/$VPK_NAME"

if sudo -u "$STEAM_USER" test -f "$TARGET"; then
  skip "$TARGET already exists (delete it first to re-download)"
else
  if ! sudo -u "$STEAM_USER" test -x "$STEAMCMD_DIR/steamcmd.sh"; then
    err "SteamCMD not found at $STEAMCMD_DIR. Run install-steamcmd.sh first."
    exit 1
  fi

  if ! sudo -u "$STEAM_USER" test -d "$GAME_DIR/addons"; then
    err "addons dir $GAME_DIR/addons does not exist. Install L4D2 first."
    exit 1
  fi

  info "Downloading workshop item $WORKSHOP_ITEM via SteamCMD (anonymous)"
  sudo -u "$STEAM_USER" -H bash -c "
    set -euo pipefail
    cd '$STEAMCMD_DIR'
    ./steamcmd.sh +login anonymous \
      +workshop_download_item 550 $WORKSHOP_ITEM validate \
      +quit
  "

  CONTENT_DIR="$STEAM_HOME/Steam/steamapps/workshop/content/550/$WORKSHOP_ITEM"

  if ! sudo -u "$STEAM_USER" test -d "$CONTENT_DIR"; then
    err "Workshop content dir not found: $CONTENT_DIR"
    err "SteamCMD may have failed silently — re-run with output visible to debug."
    exit 1
  fi

  info "Locating downloaded map file in $CONTENT_DIR"
  SRC="$(find "$CONTENT_DIR" -maxdepth 1 -type f \
           \( -name '*_legacy.bin' -o -name '*.vpk' -o -name '*.bin' \) \
           -print -quit)"

  if [ -z "${SRC:-}" ]; then
    err "No map file found in $CONTENT_DIR (expected *_legacy.bin / *.vpk / *.bin)"
    exit 1
  fi

  info "Copying $SRC -> $TARGET"
  sudo -u "$STEAM_USER" cp "$SRC" "$TARGET"
  ok "Installed at $TARGET"
fi

# Register BSPs in SourceMod's adminmenu_maplist.ini so `sm_map <name>` works
# in the in-game admin console without manual edits. Runs even when the VPK
# was already installed, so re-running the script re-syncs the maplist.
MAPLIST="$GAME_DIR/addons/sourcemod/configs/adminmenu_maplist.ini"
if sudo -u "$STEAM_USER" test -f "$MAPLIST"; then
  MAPS="$(strings "$TARGET" | grep -oE '^maps/[a-z0-9_]+\.bsp$' | sed 's|maps/||; s|\.bsp$||' | sort -u)"
  added=0
  for m in $MAPS; do
    if sudo -u "$STEAM_USER" grep -qE '^[[:space:]]*"'"$m"'"[[:space:]]*$' "$MAPLIST"; then
      continue
    fi
    sudo -u "$STEAM_USER" sed -i "/^}\$/i\\    \"$m\"" "$MAPLIST"
    ok "Registered '$m' in adminmenu_maplist.ini"
    added=$((added + 1))
  done
  if [ "$added" -gt 0 ]; then
    info "Reload SourceMod to pick up the new maps: \`sm plugins refresh\` via rcon, or \`sudo systemctl restart l4d2\`"
  fi
fi
