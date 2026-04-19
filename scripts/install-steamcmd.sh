#!/usr/bin/env bash
#
# Step 3: install SteamCMD for the 'steam' user.
#
# Downloads steamcmd_linux.tar.gz (unless already installed) and creates the
# sdk32/steamclient.so symlink expected by L4D2 and other Source games.
#
# Idempotent — skips the download if SteamCMD is already present.
# Re-runs always refresh the sdk32 symlink.

set -euo pipefail
source "$(cd "$(dirname "$0")" && pwd)/_common.sh"

STEAMCMD_URL="https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz"

require_root "$@"
require_user "$STEAM_USER"

info "Target: $STEAMCMD_DIR"

if sudo -u "$STEAM_USER" test -x "$STEAMCMD_DIR/steamcmd.sh" \
   && sudo -u "$STEAM_USER" test -f "$STEAMCMD_DIR/linux32/steamclient.so"; then
  skip "SteamCMD already installed in $STEAMCMD_DIR"
else
  info "Downloading SteamCMD from $STEAMCMD_URL"
  sudo -u "$STEAM_USER" -H bash -c "
    set -euo pipefail
    mkdir -p '$STEAMCMD_DIR'
    cd '$STEAMCMD_DIR'
    wget -q --show-progress '$STEAMCMD_URL' -O steamcmd_linux.tar.gz
    tar -xzf steamcmd_linux.tar.gz
    rm -f steamcmd_linux.tar.gz
  "
  ok "SteamCMD installed"
fi

info "Ensuring sdk32/steamclient.so symlink"
sudo -u "$STEAM_USER" -H bash -c "
  set -euo pipefail
  mkdir -p '$STEAM_HOME/.steam/sdk32'
  ln -sf '$STEAMCMD_DIR/linux32/steamclient.so' '$STEAM_HOME/.steam/sdk32/steamclient.so'
"
ok "sdk32 symlink in place"

cat <<EOF

Next:
  sudo -u $STEAM_USER -H bash -lc 'cd $STEAMCMD_DIR && ./steamcmd.sh'

Inside the SteamCMD console:
  force_install_dir $L4D2_DIR
  login <your_steam_login>
  app_update 222860 validate
  quit

anonymous login does not produce a working Linux build for app 222860 —
use a real Steam account that owns Left 4 Dead 2.
EOF
