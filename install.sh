#!/bin/bash
set -euo pipefail

APP_DIR="/opt/church-bells"
SERVICE_FILE="/etc/systemd/system/churchbell.service"
SERVICE_USER="churchbells"

echo "=== ChurchBell Installer ==="
echo "Installing into: $APP_DIR"
echo ""

# ------------------------------------------------------------
# 1. System packages
# ------------------------------------------------------------
echo "[1/7] Installing system dependencies..."
sudo apt update
sudo apt install -y \
    python3 python3-pip python3-venv \
    git cron sqlite3 libsqlite3-dev \
    alsa-utils dos2unix

# ------------------------------------------------------------
# 2. Create service user
# ------------------------------------------------------------
if ! id "$SERVICE_USER" &>/dev/null; then
  sudo adduser --system --group --home "$APP_DIR" "$SERVICE_USER"
  echo "[INFO] Created service user $SERVICE_USER"
fi

# ------------------------------------------------------------
# 3. Create application directories
# ------------------------------------------------------------
echo "[2/7] Creating application directories..."
mkdir -p "$APP_DIR"
mkdir -p "$APP_DIR/sounds"
mkdir -p "$APP_DIR/templates"
mkdir -p "$APP_DIR/static"
mkdir -p "$APP_DIR/backups"

# Ensure ownership
sudo chown -R "$SERVICE_USER":"$SERVICE_USER" "$APP_DIR"

# ------------------------------------------------------------
# 4. Python virtual environment
# ------------------------------------------------------------
echo "[3/7] Setting up Python virtual environment..."
cd "$APP_DIR"
if [ ! -d "venv" ]; then
    sudo -u "$SERVICE_USER" python3 -m venv venv
fi

source venv/bin/activate

# ------------------------------------------------------------
# 5. Install Python dependencies
# ------------------------------------------------------------
echo "[4/7] Installing Python packages..."
pip install --upgrade pip
pip install flask

# ------------------------------------------------------------
# 6. Permissions for scripts
# ------------------------------------------------------------
echo "[5/7] Setting script permissions..."
SCRIPTS=(install.sh update.sh sync_cron.py play_alarm.sh backup.sh restore.sh diagnostics.sh factory_reset.sh postinstall.sh list_alarms.sh uninstall.sh)
for script in "${SCRIPTS[@]}"; do
  if [ -f "$APP_DIR/$script" ]; then
    chmod +x "$APP_DIR/$script"
    echo "[OK] $script marked executable"
  fi
done

# ------------------------------------------------------------
# 7. Systemd service
# ------------------------------------------------------------
echo "[6/7] Installing systemd service..."

sudo bash -c "cat > $SERVICE_FILE" <<EOF
[Unit]
Description=ChurchBell Web UI
After=network.target sound.target

[Service]
User=$SERVICE_USER
WorkingDirectory=$APP_DIR
ExecStart=$APP_DIR/venv/bin/python app.py
Restart=always

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable churchbell.service
sudo systemctl restart churchbell.service

# ------------------------------------------------------------
# 8. Cron setup
# ------------------------------------------------------------
echo "[7/7] Ensuring cron is running..."
sudo systemctl enable cron
sudo systemctl start cron

echo "Syncing cron with current alarms..."
python3 "$APP_DIR/sync_cron.py" || true

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
