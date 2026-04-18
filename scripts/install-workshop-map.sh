#!/usr/bin/env bash
#
# Install an L4D2 Steam Workshop map into the dedicated server.
#
# Downloads a workshop item via anonymous SteamCMD and copies the resulting
# file into addons/ as a .vpk. Idempotent: skips the download if the target
# VPK already exists (set FORCE=1 to re-download).
#
# Required env var:
#   WORKSHOP_ITEM  workshop file id (digits), e.g. 1432537029
#
# Optional:
#   VPK_NAME        destination filename in addons/
#                   (default: workshop_<WORKSHOP_ITEM>.vpk)
#   WORKSHOP_APPID  default 550 (Left 4 Dead 2)
#   FORCE           set 1 to re-download even if the VPK already exists

set -euo pipefail
source "$(cd "$(dirname "$0")" && pwd)/_common.sh"

WORKSHOP_APPID="${WORKSHOP_APPID:-550}"
WORKSHOP_ITEM="${WORKSHOP_ITEM:-}"
VPK_NAME="${VPK_NAME:-}"
FORCE="${FORCE:-0}"

if [ -z "$WORKSHOP_ITEM" ]; then
  err "WORKSHOP_ITEM is required."
  err "Example: sudo WORKSHOP_ITEM=1432537029 bash $0"
  exit 2
fi

if [ -z "$VPK_NAME" ]; then
  VPK_NAME="workshop_${WORKSHOP_ITEM}.vpk"
fi

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
