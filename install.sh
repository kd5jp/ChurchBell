#!/bin/bash
set -e

APP_DIR="/home/pi/ChurchBell"
SERVICE_FILE="/etc/systemd/system/churchbell.service"

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
# 2. Create directories
# ------------------------------------------------------------
echo "[2/7] Creating application directories..."
mkdir -p "$APP_DIR"
mkdir -p "$APP_DIR/sounds"
mkdir -p "$APP_DIR/templates"
mkdir -p "$APP_DIR/static"

# ------------------------------------------------------------
# 3. Python virtual environment
# ------------------------------------------------------------
echo "[3/7] Setting up Python virtual environment..."
cd "$APP_DIR"
if [ ! -d "venv" ]; then
    python3 -m venv venv
fi

source venv/bin/activate

# ------------------------------------------------------------
# 4. Install Python dependencies
# ------------------------------------------------------------
echo "[4/7] Installing Python packages..."
pip install --upgrade pip
pip install flask

# ------------------------------------------------------------
# 5. Permissions for scripts
# ------------------------------------------------------------
echo "[5/7] Setting script permissions..."
chmod +x "$APP_DIR/install.sh" || true
chmod +x "$APP_DIR/update.sh" || true
chmod +x "$APP_DIR/sync_cron.py" || true
chmod +x "$APP_DIR/play_alarm.sh" || true

chown -R pi:pi "$APP_DIR"

# ------------------------------------------------------------
# 6. Systemd service
# ------------------------------------------------------------
echo "[6/7] Installing systemd service..."

sudo bash -c "cat > $SERVICE_FILE" <<EOF
[Unit]
Description=ChurchBell Web UI
After=network.target sound.target

[Service]
User=pi
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
# 7. Cron setup
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
