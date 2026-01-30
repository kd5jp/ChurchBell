#!/bin/bash
set -euo pipefail

SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Detect project directory: use git root if available, otherwise script directory
# Still allows CHURCHBELL_APP_DIR override for flexibility
if [ -z "${CHURCHBELL_APP_DIR:-}" ]; then
    if command -v git >/dev/null 2>&1 && git rev-parse --show-toplevel >/dev/null 2>&1; then
        APP_DIR="$(cd "$SOURCE_DIR" && git rev-parse --show-toplevel)"
    else
        APP_DIR="$SOURCE_DIR"
    fi
else
    APP_DIR="$CHURCHBELL_APP_DIR"
fi

# Safety check: prevent running as root directly
if [ "$EUID" -eq 0 ]; then
    echo "ERROR: Do not run this script directly as root (sudo)."
    echo "Run it as a regular user; it will prompt for sudo when needed."
    exit 1
fi

SERVICE_FILE="/etc/systemd/system/churchbell.service"
HOME_SERVICE_FILE="/etc/systemd/system/churchbell-home.service"
SERVICE_USER="${CHURCHBELL_SERVICE_USER:-churchbells}"
ADMIN_USER="${CHURCHBELL_ADMIN_USER:-admin}"
ADMIN_PASS="${CHURCHBELL_ADMIN_PASS:-changeme}"

echo "=== ChurchBell Installer ==="
echo "Installing into: $APP_DIR"
echo "Service user: $SERVICE_USER"
echo ""

# ------------------------------------------------------------
# 1. System packages
# ------------------------------------------------------------
echo "[1/8] Installing system dependencies..."
sudo apt update
sudo apt install -y \
    python3 python3-pip python3-venv \
    git cron sqlite3 libsqlite3-dev \
    alsa-utils dos2unix rsync

# ------------------------------------------------------------
# 2. Create service user
# ------------------------------------------------------------
if ! id "$SERVICE_USER" &>/dev/null; then
  sudo adduser --system --group --home "$APP_DIR" "$SERVICE_USER"
  echo "[INFO] Created service user $SERVICE_USER"
fi
sudo usermod -aG audio,video,gpio,input,spi,i2c,dialout "$SERVICE_USER" || true

# ------------------------------------------------------------
# 3. Sync application files
# ------------------------------------------------------------
echo "[2/8] Syncing application files..."
sudo mkdir -p "$APP_DIR"
sudo rsync -a \
    --exclude "venv" \
    --exclude "bells.db" \
    --exclude "sounds" \
    --exclude "backups" \
    "$SOURCE_DIR"/ "$APP_DIR"/

# Set ownership immediately after rsync to prevent permission issues
sudo chown -R "$SERVICE_USER":"$SERVICE_USER" "$APP_DIR"

# ------------------------------------------------------------
# 4. Create application directories
# ------------------------------------------------------------
echo "[3/8] Creating application directories..."
mkdir -p "$APP_DIR/sounds"
mkdir -p "$APP_DIR/templates"
mkdir -p "$APP_DIR/static"
mkdir -p "$APP_DIR/backups"

# ------------------------------------------------------------
# 5. Python virtual environment
# ------------------------------------------------------------
echo "[4/8] Setting up Python virtual environment..."
cd "$APP_DIR"
if [ ! -d "venv" ]; then
    sudo -u "$SERVICE_USER" python3 -m venv venv
fi

source venv/bin/activate

# ------------------------------------------------------------
# 6. Install Python dependencies
# ------------------------------------------------------------
echo "[5/8] Installing Python packages..."
pip install --upgrade pip
pip install flask

# ------------------------------------------------------------
# 7. Permissions for scripts
# ------------------------------------------------------------
echo "[6/8] Setting script permissions..."
SCRIPTS=(install.sh update.sh sync_cron.py update_play_alarm_path.py play_alarm.sh backup.sh restore.sh diagnostics.sh factory_reset.sh postinstall.sh list_alarms.sh uninstall.sh)
for script in "${SCRIPTS[@]}"; do
  if [ -f "$APP_DIR/$script" ]; then
    chmod +x "$APP_DIR/$script"
    echo "[OK] $script marked executable"
  fi
done

# ------------------------------------------------------------
# 8. Systemd services
# ------------------------------------------------------------
echo "[7/8] Installing systemd services..."

sudo bash -c "cat > $SERVICE_FILE" <<EOF
[Unit]
Description=ChurchBell Web UI
After=network.target sound.target

[Service]
User=$SERVICE_USER
WorkingDirectory=$APP_DIR
Environment="CHURCHBELL_ADMIN_USER=${ADMIN_USER}"
Environment="CHURCHBELL_ADMIN_PASS=${ADMIN_PASS}"
ExecStart=$APP_DIR/venv/bin/python app.py
Restart=always

[Install]
WantedBy=multi-user.target
EOF

sudo bash -c "cat > $HOME_SERVICE_FILE" <<EOF
[Unit]
Description=ChurchBell Home UI
After=network.target sound.target

[Service]
User=$SERVICE_USER
WorkingDirectory=$APP_DIR
ExecStart=$APP_DIR/venv/bin/python home.py
Restart=always
AmbientCapabilities=CAP_NET_BIND_SERVICE
CapabilityBoundingSet=CAP_NET_BIND_SERVICE
NoNewPrivileges=true

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable churchbell.service
sudo systemctl enable churchbell-home.service
sudo systemctl restart churchbell.service
sudo systemctl restart churchbell-home.service

# ------------------------------------------------------------
# 9. Cron setup
# ------------------------------------------------------------
echo "[8/8] Ensuring cron is running..."
sudo systemctl enable cron
sudo systemctl start cron

echo "Syncing cron with current alarms..."
python3 "$APP_DIR/sync_cron.py" || true

echo "Updating play_alarm.sh with correct project path..."
python3 "$APP_DIR/update_play_alarm_path.py" || true

# ------------------------------------------------------------
# Done
# ------------------------------------------------------------
echo ""
echo "=== ChurchBell installation complete ==="
echo "Service is running on port 8080"
echo "Visit: http://<your-pi-ip>:8080"
echo ""

# Final ownership sweep
sudo chown -R "$SERVICE_USER":"$SERVICE_USER" "$APP_DIR"
