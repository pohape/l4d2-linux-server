#!/usr/bin/env bash
#
# Verify an l4d2-linux-server install.
#
# Runs read-only checks and prints a PASS/FAIL summary.
# Exits 0 when all required checks pass, non-zero otherwise.
#
# Run as root (or via sudo). WARN results do not affect the exit code.
#
# Environment overrides (defaults in parentheses):
#   STEAM_USER  (steam)         OS user that owns the install
#   STEAM_HOME  (/home/steam)   home directory of STEAM_USER
#   L4D2_DIR    ($STEAM_HOME/l4d2)
#   L4D2_PORT   (27015)
#   SERVICE     (l4d2)          systemd unit name

set -u

STEAM_USER="${STEAM_USER:-steam}"
STEAM_HOME="${STEAM_HOME:-/home/$STEAM_USER}"
L4D2_DIR="${L4D2_DIR:-$STEAM_HOME/l4d2}"
GAME_DIR="$L4D2_DIR/left4dead2"
L4D2_PORT="${L4D2_PORT:-27015}"
SERVICE="${SERVICE:-l4d2}"

if [ "${EUID:-$(id -u)}" -ne 0 ]; then
  echo "verify-install.sh must run as root. Try: sudo $0" >&2
  exit 2
fi

if [ -t 1 ]; then
  C_RED=$'\033[31m'; C_GREEN=$'\033[32m'; C_YELLOW=$'\033[33m'
  C_BOLD=$'\033[1m';  C_RESET=$'\033[0m'
else
  C_RED=""; C_GREEN=""; C_YELLOW=""; C_BOLD=""; C_RESET=""
fi

PASSED=0
FAILED=0
WARNED=0

pass() { printf "  %sPASS%s  %s\n" "$C_GREEN" "$C_RESET" "$1"; PASSED=$((PASSED+1)); }
fail() { printf "  %sFAIL%s  %s\n" "$C_RED"   "$C_RESET" "$1"; FAILED=$((FAILED+1)); }
warn() { printf "  %sWARN%s  %s\n" "$C_YELLOW" "$C_RESET" "$1"; WARNED=$((WARNED+1)); }

section() { printf "\n%s%s%s\n" "$C_BOLD" "$1" "$C_RESET"; }

check_file() {
  if [ -f "$1" ]; then pass "$2: $1"; else fail "$2 missing: $1"; fi
}

check_dir() {
  if [ -d "$1" ]; then pass "$2: $1"; else fail "$2 missing: $1"; fi
}

section "System prerequisites"

if id "$STEAM_USER" >/dev/null 2>&1; then
  pass "User '$STEAM_USER' exists"
else
  fail "User '$STEAM_USER' does not exist"
fi

if dpkg --print-foreign-architectures 2>/dev/null | grep -q '^i386$'; then
  pass "dpkg architecture i386 enabled"
else
  fail "dpkg architecture i386 not enabled (run: dpkg --add-architecture i386)"
fi

for pkg in lib32gcc-s1 lib32stdc++6 libc6-i386; do
  if dpkg-query -W -f='${Status}' "$pkg" 2>/dev/null | grep -q '^install ok installed$'; then
    pass "Package installed: $pkg"
  else
    fail "Package missing: $pkg"
  fi
done

section "L4D2 server files"
check_file "$L4D2_DIR/srcds_run"        "srcds_run"
check_file "$L4D2_DIR/srcds_linux"      "srcds_linux"
check_dir  "$GAME_DIR"                  "left4dead2 game dir"
check_file "$GAME_DIR/cfg/server.cfg"   "server.cfg"

section "Metamod:Source"
check_file "$GAME_DIR/addons/metamod.vdf" "metamod.vdf"
check_dir  "$GAME_DIR/addons/metamod"     "metamod directory"

section "SourceMod"
check_dir  "$GAME_DIR/addons/sourcemod"              "sourcemod directory"
check_dir  "$GAME_DIR/addons/sourcemod/plugins"      "sourcemod plugins directory"
check_file "$GAME_DIR/addons/sourcemod/configs/admins_simple.ini" "admins_simple.ini"

if [ -f "$GAME_DIR/addons/sourcemod/plugins/nextmap.smx" ]; then
  warn "nextmap.smx is active (move it to plugins/disabled/ to avoid forced rotation)"
fi

section "Configuration"
CFG="$GAME_DIR/cfg/server.cfg"
if [ -f "$CFG" ]; then
  if grep -qE '^[[:space:]]*rcon_password[[:space:]]+"CHANGE_ME"' "$CFG"; then
    fail "rcon_password is still the default CHANGE_ME in $CFG"
  elif grep -qE '^[[:space:]]*rcon_password[[:space:]]+"[^"]+"' "$CFG"; then
    pass "rcon_password is set"
  else
    fail "rcon_password directive missing in $CFG"
  fi
fi

ADMINS="$GAME_DIR/addons/sourcemod/configs/admins_simple.ini"
if [ -f "$ADMINS" ]; then
  if grep -qE '^[[:space:]]*"STEAM_[0-9]+:[0-9]+:[0-9]+"' "$ADMINS"; then
    pass "At least one admin configured in admins_simple.ini"
  else
    warn "No admins configured (sm_admin will not work until you add SteamIDs)"
  fi
fi

section "systemd service"
UNIT_PATH="/etc/systemd/system/$SERVICE.service"
check_file "$UNIT_PATH" "systemd unit"

if systemctl is-enabled "$SERVICE" >/dev/null 2>&1; then
  pass "Service is enabled"
else
  fail "Service is not enabled (run: systemctl enable $SERVICE)"
fi

if systemctl is-active "$SERVICE" >/dev/null 2>&1; then
  pass "Service is active (running)"
else
  fail "Service is not active (check: journalctl -u $SERVICE -n 100)"
fi

section "Network"
if ss -H -lntu 2>/dev/null | awk '{print $5}' | grep -qE "[:.]${L4D2_PORT}\$"; then
  pass "Port $L4D2_PORT is listening"
else
  fail "Port $L4D2_PORT is not listening"
fi

section "Recent logs"
if journalctl -u "$SERVICE" -n 200 --no-pager 2>/dev/null \
    | grep -iE 'segmentation fault|core dumped|cannot open shared object|assertion .* failed' >/dev/null; then
  fail "Crash indicators found in last 200 log lines (check: journalctl -u $SERVICE -n 200)"
else
  pass "No crash indicators in last 200 log lines"
fi

section "Summary"
printf "  %sPASSED%s %d   %sFAILED%s %d   %sWARN%s %d\n\n" \
  "$C_GREEN"  "$C_RESET" "$PASSED" \
  "$C_RED"    "$C_RESET" "$FAILED" \
  "$C_YELLOW" "$C_RESET" "$WARNED"

[ "$FAILED" -eq 0 ]
