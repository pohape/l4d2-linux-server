#!/usr/bin/env bash
#
# Step 7: reload systemd, enable and start the l4d2 service, then run the
# verification script.
#
# Idempotent: if the service is already enabled/active, systemctl is a
# no-op. Exits with the exit code of verify-install.sh.

set -euo pipefail
source "$(cd "$(dirname "$0")" && pwd)/_common.sh"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

require_root "$@"

L4D2_PORT="${L4D2_PORT:-27015}"
PORT_WAIT_SECONDS="${PORT_WAIT_SECONDS:-30}"

info "Reloading systemd daemon"
systemctl daemon-reload

info "Enabling and starting $SERVICE.service"
systemctl enable --now "$SERVICE.service"

info "Waiting up to ${PORT_WAIT_SECONDS}s for port $L4D2_PORT to start listening"
waited=0
while [ "$waited" -lt "$PORT_WAIT_SECONDS" ]; do
  if ss -H -lntu 2>/dev/null | awk '{print $5}' | grep -qE "[:.]${L4D2_PORT}\$"; then
    ok "Port $L4D2_PORT is listening (after ${waited}s)"
    break
  fi
  sleep 1
  waited=$((waited + 1))
done

exec bash "$SCRIPT_DIR/verify-install.sh"
