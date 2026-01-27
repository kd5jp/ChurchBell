#!/usr/bin/env bash
set -euo pipefail

APP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SERVICE_HOME="churchbells-home.service"
SERVICE_MAIN="churchbells.service"

echo "[INFO] Updating ChurchBell..."

cd "$APP_DIR"

# Optional: pull latest code if repo exists
if [ -d .git ]; then
  echo "[INFO] Pulling latest changes from GitHub..."
  git fetch --all
  git reset --hard origin/main || true
fi

# Ensure correct ownership
echo "[INFO] Ensuring pi owns the application directory..."
sudo chown -R pi:pi "$APP_DIR"

# Update Python environment
if [ -d venv ]; then
  echo "[INFO] Updating Python dependencies..."
  source venv/bin/activate
  pip install --upgrade pip
  pip install flask
  deactivate
else
  echo "[WARN] No virtual environment found. Run install.sh first."
fi
echo "[INFO] Normalizing script permissions..."
if ls "$APP_DIR"/*.sh >/dev/null 2>&1; then
  chmod +x "$APP_DIR"/*.sh
  echo "[INFO] Script permissions updated."
else
  echo "[INFO] No .sh scripts found to chmod."
fi
chmod +x "$APP_DIR/sync_cron.py"
chmod +x "$APP_DIR/play_alarm.sh"
# Restart services
echo "[INFO] Restarting systemd services..."
sudo systemctl daemon-reload
sudo systemctl restart "$SERVICE_HOME" || true
sudo systemctl restart "$SERVICE_MAIN" || true

echo "[INFO] Update complete."
echo "[INFO] Services restarted successfully."
