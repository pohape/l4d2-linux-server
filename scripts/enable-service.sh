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

info "Giving srcds_linux a moment to bind the port"
sleep 3

exec bash "$SCRIPT_DIR/verify-install.sh"
