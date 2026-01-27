#!/bin/bash
set -e

APP_DIR="${CHURCHBELL_APP_DIR:-/opt/church-bells}"
VENV_DIR="$APP_DIR/venv"
SERVICE_NAME="churchbell.service"
HOME_SERVICE_NAME="churchbell-home.service"
SERVICE_USER="${CHURCHBELL_SERVICE_USER:-churchbells}"

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
echo "[INFO] Fixing script permissions..."

# List of scripts to normalize
SCRIPTS=(
  diagnostics.sh
  install.sh
  restore.sh
  update.sh
  backup.sh
  factory_reset.sh
  postinstall.sh
  list_alarms.sh
  uninstall.sh
)

for script in "${SCRIPTS[@]}"; do
  if [ -f "$APP_DIR/$script" ]; then
    chmod +x "$APP_DIR/$script"
    echo "[OK] $script marked executable"
  else
    echo "[WARN] $script not found in $APP_DIR"
  fi
done


chown -R "$SERVICE_USER":"$SERVICE_USER" "$APP_DIR"

# ------------------------------------------------------------
# 5. Sync cron with DB alarms
# ------------------------------------------------------------
echo "[5/6] Syncing cron with alarms..."
python3 "$APP_DIR/sync_cron.py" || true

# ------------------------------------------------------------
# 6. Restart systemd service
# ------------------------------------------------------------
echo "[6/6] Restarting ChurchBell services..."
sudo systemctl daemon-reload
sudo systemctl restart "$SERVICE_NAME"
sudo systemctl restart "$HOME_SERVICE_NAME"

echo ""
echo "=== Update complete ==="
echo "ChurchBell is now running the latest version."
echo ""
