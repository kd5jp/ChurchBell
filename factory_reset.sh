#!/bin/bash
set -euo pipefail

APP_DIR="${CHURCHBELL_APP_DIR:-/opt/church-bells}"
LOG_DIR="/var/log/churchbell"
LOGFILE="${LOG_DIR}/factory_reset.log"
SERVICE_NAME="churchbell.service"
HOME_SERVICE_NAME="churchbell-home.service"
PURGE=false

# Parse arguments
for arg in "$@"; do
  case $arg in
    --purge) PURGE=true ;;
    *) echo "Unknown option: $arg" ;;
  esac
done

sudo mkdir -p "$LOG_DIR"
echo "=== Factory reset started at $(date) ===" | tee -a "$LOGFILE"

# Stop services
systemctl stop "$SERVICE_NAME" || true
systemctl stop "$HOME_SERVICE_NAME" || true

# Purge mode
if [ "$PURGE" = true ]; then
  echo "[INFO] Purging user data..." | tee -a "$LOGFILE"
  rm -rf "$APP_DIR/sounds/"*
  rm -rf "$APP_DIR/backups/"*
else
  echo "[INFO] Preserving user data (sounds, backups, schedules)" | tee -a "$LOGFILE"
fi

# Reset database and cron
echo "[INFO] Resetting database..." | tee -a "$LOGFILE"
rm -f "$APP_DIR/bells.db"

PYTHON_BIN="$APP_DIR/venv/bin/python"
if [ ! -x "$PYTHON_BIN" ]; then
  PYTHON_BIN="python3"
fi

cd "$APP_DIR"
$PYTHON_BIN -c "import app; app.init_db()" >> "$LOGFILE" 2>&1 || true
$PYTHON_BIN "$APP_DIR/sync_cron.py" >> "$LOGFILE" 2>&1 || true

# Restart service
systemctl start "$SERVICE_NAME"
systemctl start "$HOME_SERVICE_NAME"

echo "=== Factory reset completed at $(date) ===" | tee -a "$LOGFILE"
