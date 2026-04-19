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

info "Reloading systemd daemon"
systemctl daemon-reload

info "Enabling and starting $SERVICE.service"
systemctl enable --now "$SERVICE.service"

info "Waiting up to 30s for port 27015 to start listening"
waited=0
while [ "$waited" -lt 30 ]; do
  if ss -H -lntu 2>/dev/null | awk '{print $5}' | grep -qE '[:.]27015$'; then
    ok "Port 27015 is listening (after ${waited}s)"
    break
  fi
  sleep 1
  waited=$((waited + 1))
done

exec "$SCRIPT_DIR/verify-install.sh"
