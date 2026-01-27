#!/bin/bash
set -e

APP_DIR="/home/pi/ChurchBell"
VENV_DIR="$APP_DIR/venv"
SERVICE_NAME="churchbell.service"

echo "=== ChurchBell Updater ==="
echo "Updating application in: $APP_DIR"
echo ""

# ------------------------------------------------------------
# 1. Pull latest code from GitHub
# ------------------------------------------------------------
echo "[1/6] Pulling latest changes from GitHub..."
cd "$APP_DIR"
git reset --hard HEAD
git pull --rebase

# ------------------------------------------------------------
# 2. Ensure Python venv exists
# ------------------------------------------------------------
echo "[2/6] Ensuring Python virtual environment exists..."
if [ ! -d "$VENV_DIR" ]; then
    echo "Virtual environment missing — creating..."
    python3 -m venv "$VENV_DIR"
fi

source "$VENV_DIR/bin/activate"

# ------------------------------------------------------------
# 3. Install/update Python dependencies
# ------------------------------------------------------------
echo "[3/6] Updating Python packages..."
pip install --upgrade pip
pip install flask

# ------------------------------------------------------------
# 4. Fix permissions (self‑healing)
# ------------------------------------------------------------
echo "Fixing script permissions..."
chmod +x "$APP_DIR/*.sh" || true


chown -R pi:pi "$APP_DIR"

# ------------------------------------------------------------
# 5. Sync cron with DB alarms
# ------------------------------------------------------------
echo "[5/6] Syncing cron with alarms..."
python3 "$APP_DIR/sync_cron.py" || true

# ------------------------------------------------------------
# 6. Restart systemd service
# ------------------------------------------------------------
echo "[6/6] Restarting ChurchBell service..."
sudo systemctl daemon-reload
sudo systemctl restart "$SERVICE_NAME"

echo ""
echo "=== Update complete ==="
echo "ChurchBell is now running the latest version."
echo ""
