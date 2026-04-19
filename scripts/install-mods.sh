#!/usr/bin/env bash
#
# Install the verified mod stack into the L4D2 server.
#
# SourceMod plugins (downloaded into addons/sourcemod/):
#   - hp_tank_show   — sprite above a tank's head (green → red by HP)
#   - abm            — Advanced Bot Manager: auto-spawns survivor bots to
#                       keep the team at 4, and on player death shows a
#                       numbered menu to take over any living bot. Works
#                       on campaigns AND on arena-style maps.
#   - left4dhooks    — required dependency (L4D hooks + gamedata)
#
# Steam Workshop VScript addons (downloaded via install-workshop-map.sh):
#   - Left 4 Lib     — dependency for Left 4 Bots 2
#   - Left 4 Bots 2  — smart survivor bot AI (defib, scavenge, smarter
#                       combat, follow-leader, etc.)
#
# Idempotent: skips files that already exist. Pass FORCE=1 to re-download
# everything. Files are written under /home/steam/l4d2/left4dead2/.
#
# After running, restart the service to load everything:
#   sudo systemctl restart l4d2

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/_common.sh"

FORCE="${FORCE:-0}"

require_root "$@"
require_user "$STEAM_USER"

SM_DIR="$GAME_DIR/addons/sourcemod"

if ! sudo -u "$STEAM_USER" test -d "$SM_DIR/plugins"; then
  err "SourceMod not installed (missing $SM_DIR/plugins). Run install-mms-sm.sh first."
  exit 1
fi

BASE_LDH="https://raw.githubusercontent.com/SilvDev/Left4DHooks/master/sourcemod"
BASE_FBE="https://raw.githubusercontent.com/fbef0102/L4D1_2-Plugins/master"
BASE_BTS="https://raw.githubusercontent.com/Beats0/L4D2-Linux-Server-Package/master/left4dead2"
CFG_DIR="$GAME_DIR/cfg"

DOWNLOADS=(
  "$BASE_LDH/plugins/left4dhooks.smx|$SM_DIR/plugins/left4dhooks.smx"
  "$BASE_LDH/gamedata/left4dhooks.l4d2.txt|$SM_DIR/gamedata/left4dhooks.l4d2.txt"
  "$BASE_LDH/gamedata/lux_library.txt|$SM_DIR/gamedata/lux_library.txt"
  "$BASE_LDH/data/left4dhooks.l4d2.cfg|$SM_DIR/data/left4dhooks.l4d2.cfg"
  "$BASE_FBE/hp_tank_show/plugins/hp_tank_show.smx|$SM_DIR/plugins/hp_tank_show.smx"
  "$BASE_BTS/addons/sourcemod/plugins/abm.smx|$SM_DIR/plugins/abm.smx"
  "$BASE_BTS/addons/sourcemod/gamedata/abm.txt|$SM_DIR/gamedata/abm.txt"
  "$BASE_BTS/cfg/sourcemod/abm.cfg|$CFG_DIR/sourcemod/abm.cfg"
)

sudo -u "$STEAM_USER" mkdir -p "$SM_DIR/data" "$SM_DIR/gamedata" "$CFG_DIR/sourcemod"

for entry in "${DOWNLOADS[@]}"; do
  url="${entry%%|*}"
  dst="${entry##*|}"

  if sudo -u "$STEAM_USER" test -f "$dst" && [ "$FORCE" != "1" ]; then
    skip "$(basename "$dst") already exists"
    continue
  fi

  info "Downloading $(basename "$dst")"
  sudo -u "$STEAM_USER" curl -fsSL "$url" -o "$dst"
  ok "-> $dst"
done

section() { printf "\n%s%s%s\n" "$C_BOLD" "$1" "$C_RESET"; }

section "Installing Steam Workshop VScript addons"

# Left 4 Lib first (dependency), then Left 4 Bots 2.
for wid in 2634208272 3022416274; do
  FORCE="$FORCE" WORKSHOP_ITEM="$wid" bash "$SCRIPT_DIR/install-workshop-map.sh"
done

cat <<EOF

Everything in place. Reload to activate:
  sudo systemctl restart l4d2

cvar configs of interest:
  - cfg/sourcemod/abm.cfg                  (abm_offertakeover, abm_minplayers, …)
  - cfg/sourcemod/hp_tank_show.cfg         (auto-generated on first load)
  - left4dead2/left4bots2/cfg/convars.txt  (Left 4 Bots 2 behaviour tuning)

Expected in-game behaviour:
  - smart survivor bots defib, scavenge, follow
  - when you die, a numbered menu appears listing the live bots — press a
    digit to take over that bot and keep playing
EOF
