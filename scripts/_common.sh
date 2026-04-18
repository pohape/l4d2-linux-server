# Common helpers for l4d2-linux-server install scripts.
#
# Sourced by sibling scripts via:
#   source "$(dirname "$0")/_common.sh"
#
# Not meant to be executed directly.

STEAM_USER="${STEAM_USER:-steam}"
STEAM_HOME="${STEAM_HOME:-/home/$STEAM_USER}"
L4D2_DIR="${L4D2_DIR:-$STEAM_HOME/l4d2}"
GAME_DIR="${GAME_DIR:-$L4D2_DIR/left4dead2}"
STEAMCMD_DIR="${STEAMCMD_DIR:-$STEAM_HOME/steamcmd}"
SERVICE="${SERVICE:-l4d2}"

if [ -t 1 ]; then
  C_RED=$'\033[31m'
  C_GREEN=$'\033[32m'
  C_YELLOW=$'\033[33m'
  C_BLUE=$'\033[34m'
  C_BOLD=$'\033[1m'
  C_RESET=$'\033[0m'
else
  C_RED=""; C_GREEN=""; C_YELLOW=""; C_BLUE=""; C_BOLD=""; C_RESET=""
fi

info() { printf "%s[..]%s %s\n" "$C_BLUE"   "$C_RESET" "$*"; }
ok()   { printf "%s[ok]%s %s\n" "$C_GREEN"  "$C_RESET" "$*"; }
skip() { printf "%s[--]%s %s\n" "$C_YELLOW" "$C_RESET" "$*"; }
err()  { printf "%s[!!]%s %s\n" "$C_RED"    "$C_RESET" "$*" >&2; }

require_root() {
  if [ "${EUID:-$(id -u)}" -ne 0 ]; then
    err "This script must run as root. Try: sudo $0 $*"
    exit 2
  fi
}

require_user() {
  local u="$1"
  if ! id "$u" >/dev/null 2>&1; then
    err "User '$u' does not exist. Run install-packages.sh first."
    exit 1
  fi
}
