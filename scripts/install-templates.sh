#!/usr/bin/env bash
#
# Step 6: copy template files from the repo into the right places on disk.
#
# Idempotent — if a target file already exists, it is NOT overwritten. So
# you can re-run this safely and won't lose your rcon_password, hostname,
# or admin list. To reinstall a template, delete the target file first.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/_common.sh"

TEMPLATES_DIR="$(cd "$SCRIPT_DIR/.." && pwd)/templates"

require_root "$@"
require_user "$STEAM_USER"

if [ ! -d "$TEMPLATES_DIR" ]; then
  err "Templates directory not found: $TEMPLATES_DIR"
  exit 1
fi

install_file() {
  local src="$1" dst="$2" owner="$3" group="$4"

  if [ ! -f "$src" ]; then
    err "Template missing: $src"
    return 1
  fi

  if [ -e "$dst" ]; then
    skip "$dst already exists (delete it first to reinstall from template)"
    return 0
  fi

  install -D -o "$owner" -g "$group" -m 644 "$src" "$dst"
  ok "Installed $dst"
}

install_file "$TEMPLATES_DIR/server.cfg" \
  "$GAME_DIR/cfg/server.cfg" \
  "$STEAM_USER" "$STEAM_USER"

install_file "$TEMPLATES_DIR/sourcemod/admins_simple.ini" \
  "$GAME_DIR/addons/sourcemod/configs/admins_simple.ini" \
  "$STEAM_USER" "$STEAM_USER"

install_file "$TEMPLATES_DIR/sourcemod/adminmenu_maplist.ini" \
  "$GAME_DIR/addons/sourcemod/configs/adminmenu_maplist.ini" \
  "$STEAM_USER" "$STEAM_USER"

install_file "$TEMPLATES_DIR/systemd/l4d2.service" \
  "/etc/systemd/system/l4d2.service" \
  "root" "root"

cat <<EOF

Before starting the service, edit these files:
  - $GAME_DIR/cfg/server.cfg                                     (hostname, rcon_password)
  - $GAME_DIR/addons/sourcemod/configs/admins_simple.ini         (your admin SteamIDs)
EOF
