#!/usr/bin/env bash
#
# Install the Tank Challenge custom map.
#
# Downloads workshop item 151833267 (L4D2 Tank Challenge v1.5) via anonymous
# SteamCMD, and copies the resulting file into addons/ as a .vpk.
#
# Idempotent: if the target VPK already exists, the script exits without
# re-downloading. Set FORCE=1 to re-download.

set -euo pipefail
source "$(cd "$(dirname "$0")" && pwd)/_common.sh"

WORKSHOP_APPID="${WORKSHOP_APPID:-550}"
WORKSHOP_ITEM="${WORKSHOP_ITEM:-151833267}"
VPK_NAME="${VPK_NAME:-l4d2_tank_challenge.vpk}"
FORCE="${FORCE:-0}"

require_root "$@"
require_user "$STEAM_USER"

TARGET="$GAME_DIR/addons/$VPK_NAME"

if sudo -u "$STEAM_USER" test -f "$TARGET" && [ "$FORCE" != "1" ]; then
  skip "$TARGET already exists (set FORCE=1 to re-download)"
  exit 0
fi

if ! sudo -u "$STEAM_USER" test -x "$STEAMCMD_DIR/steamcmd.sh"; then
  err "SteamCMD not found at $STEAMCMD_DIR. Run install-steamcmd.sh first."
  exit 1
fi

if ! sudo -u "$STEAM_USER" test -d "$GAME_DIR/addons"; then
  err "addons dir $GAME_DIR/addons does not exist. Install L4D2 first."
  exit 1
fi

info "Downloading workshop item $WORKSHOP_APPID/$WORKSHOP_ITEM via SteamCMD (anonymous)"
sudo -u "$STEAM_USER" -H bash -c "
  set -euo pipefail
  cd '$STEAMCMD_DIR'
  ./steamcmd.sh +login anonymous \
    +workshop_download_item $WORKSHOP_APPID $WORKSHOP_ITEM validate \
    +quit
"

CONTENT_DIR="$STEAM_HOME/Steam/steamapps/workshop/content/$WORKSHOP_APPID/$WORKSHOP_ITEM"

if ! sudo -u "$STEAM_USER" test -d "$CONTENT_DIR"; then
  err "Workshop content dir not found: $CONTENT_DIR"
  err "SteamCMD may have failed silently — re-run with output visible to debug."
  exit 1
fi

info "Locating downloaded map file in $CONTENT_DIR"
SRC="$(sudo -u "$STEAM_USER" find "$CONTENT_DIR" -maxdepth 1 -type f \
         \( -name '*_legacy.bin' -o -name '*.vpk' -o -name '*.bin' \) \
         -print -quit)"

if [ -z "${SRC:-}" ]; then
  err "No map file found in $CONTENT_DIR (expected *_legacy.bin / *.vpk / *.bin)"
  exit 1
fi

info "Copying $SRC -> $TARGET"
sudo -u "$STEAM_USER" cp "$SRC" "$TARGET"
ok "Tank Challenge installed at $TARGET"

cat <<EOF

Switch to the map in-game (as an admin) with:
  sm_map l4d2_tank_challenge_15_rounds
  sm_map l4d2_tank_challenge_20_rounds
  sm_map l4d2_tank_challenge_30_rounds
EOF
