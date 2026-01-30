#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Detect project directory: use git root if available, otherwise script directory
# Still allows CHURCHBELL_APP_DIR override for flexibility
if [ -z "${CHURCHBELL_APP_DIR:-}" ]; then
    if command -v git >/dev/null 2>&1 && cd "$SCRIPT_DIR" && git rev-parse --show-toplevel >/dev/null 2>&1; then
        APP_DIR="$(cd "$SCRIPT_DIR" && git rev-parse --show-toplevel)"
    else
        APP_DIR="$SCRIPT_DIR"
    fi
else
    APP_DIR="$CHURCHBELL_APP_DIR"
fi
LOG_DIR="/var/log/churchbell"
LOGFILE="${LOG_DIR}/diagnostics.log"
SERVICE_NAME="churchbell.service"
HOME_SERVICE_NAME="churchbell-home.service"

sudo mkdir -p "$LOG_DIR"
echo "=== Diagnostics run at $(date) ===" | tee -a "$LOGFILE"

# System info
echo "[INFO] System info:" | tee -a "$LOGFILE"
uname -a | tee -a "$LOGFILE"
python3 --version | tee -a "$LOGFILE"
df -h | tee -a "$LOGFILE"
free -h | tee -a "$LOGFILE"

# Service status
echo "[INFO] Checking systemd services..." | tee -a "$LOGFILE"
systemctl status "$SERVICE_NAME" --no-pager | tee -a "$LOGFILE"
systemctl status "$HOME_SERVICE_NAME" --no-pager | tee -a "$LOGFILE"

# Ports
echo "[INFO] Checking listening ports..." | tee -a "$LOGFILE"
ss -tuln | grep -E ':80|:443|:8080' | tee -a "$LOGFILE" || echo "No expected ports found" | tee -a "$LOGFILE"

# Database check
echo "[INFO] Checking database schema..." | tee -a "$LOGFILE"
sqlite3 "$APP_DIR/bells.db" ".tables" | tee -a "$LOGFILE"

# Filesystem check
for dir in "$APP_DIR/sounds" "$APP_DIR/backups"; do
  if [ -d "$dir" ]; then
    echo "[OK] $dir exists" | tee -a "$LOGFILE"
    [ -w "$dir" ] && echo "[OK] $dir writable" | tee -a "$LOGFILE" || echo "[WARN] $dir not writable" | tee -a "$LOGFILE"
  else
    echo "[ERROR] $dir missing" | tee -a "$LOGFILE"
  fi
done

# Logs
echo "[INFO] Last 50 lines of service logs:" | tee -a "$LOGFILE"
journalctl -u "$SERVICE_NAME" -n 50 --no-pager | tee -a "$LOGFILE"
journalctl -u "$HOME_SERVICE_NAME" -n 50 --no-pager | tee -a "$LOGFILE"

echo "=== Diagnostics completed at $(date) ===" | tee -a "$LOGFILE"
