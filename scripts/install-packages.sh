#!/usr/bin/env bash
#
# Step 1: install system packages required for an L4D2 dedicated server on
# Ubuntu 22.04. Idempotent — safe to re-run.
#
# Creates the 'steam' user, enables the i386 architecture, and installs the
# runtime packages needed by srcds_linux.

set -euo pipefail
source "$(cd "$(dirname "$0")" && pwd)/_common.sh"

require_root "$@"

info "Ensuring user '$STEAM_USER' exists"
if id "$STEAM_USER" >/dev/null 2>&1; then
  skip "User '$STEAM_USER' already exists"
else
  adduser --disabled-password --gecos "" "$STEAM_USER"
  ok "Created user '$STEAM_USER'"
fi

info "Enabling i386 architecture"
if dpkg --print-foreign-architectures | grep -q '^i386$'; then
  skip "i386 already enabled"
else
  dpkg --add-architecture i386
  ok "i386 enabled"
fi

info "Running apt-get update"
apt-get update -qq

PACKAGES=(
  ca-certificates
  curl
  git
  wget
  tar
  tmux
  screen
  unzip
  jq
  lib32gcc-s1
  lib32stdc++6
  libc6-i386
)

info "Installing packages: ${PACKAGES[*]}"
DEBIAN_FRONTEND=noninteractive apt-get install -y -qq "${PACKAGES[@]}"
ok "Packages installed"
