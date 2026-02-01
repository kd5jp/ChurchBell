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
# Use the current user as the service user (no separate service user)
SERVICE_USER="${CHURCHBELL_SERVICE_USER:-$(whoami)}"
ADMIN_USER="${CHURCHBELL_ADMIN_USER:-admin}"
ADMIN_PASS="${CHURCHBELL_ADMIN_PASS:-changeme}"

echo "=== ChurchBell Installer ==="
echo "Installing into: $APP_DIR"
echo "Service user: $SERVICE_USER (current user)"
echo ""

# ------------------------------------------------------------
# 1. System packages
# ------------------------------------------------------------
echo "[1/11] Installing system dependencies..."
sudo apt update
sudo apt install -y \
    python3 python3-pip python3-venv \
    git cron sqlite3 libsqlite3-dev \
    pipewire pipewire-alsa pipewire-pulse wireplumber \
    dos2unix rsync openssl

# ------------------------------------------------------------
# 2. Ensure current user is in required groups
# ------------------------------------------------------------
CURRENT_USER="$(whoami)"
echo "[2/11] Setting up user groups..."
# Add current user to audio and other required groups
sudo usermod -aG audio,video,gpio,input,spi,i2c,dialout "$CURRENT_USER" || true
echo "[INFO] User $CURRENT_USER will be used as service user"

# ------------------------------------------------------------
# 3. Sync application files
# ------------------------------------------------------------
echo "[3/11] Syncing application files..."
sudo mkdir -p "$APP_DIR"
sudo rsync -a \
    --exclude "venv" \
    --exclude "bells.db" \
    --exclude "sounds" \
    --exclude "backups" \
    "$SOURCE_DIR"/ "$APP_DIR"/

# Set ownership to current user (service user is same as current user)
CURRENT_USER="$(whoami)"
sudo chown -R "$CURRENT_USER":"$CURRENT_USER" "$APP_DIR"
sudo chmod -R 755 "$APP_DIR"

# ------------------------------------------------------------
# 4. Create application directories
# ------------------------------------------------------------
echo "[4/11] Creating application directories..."
mkdir -p "$APP_DIR/sounds"
mkdir -p "$APP_DIR/templates"
mkdir -p "$APP_DIR/static"
mkdir -p "$APP_DIR/backups"
chown -R "$CURRENT_USER":"$CURRENT_USER" "$APP_DIR/sounds" "$APP_DIR/templates" "$APP_DIR/static" "$APP_DIR/backups" 2>/dev/null || true

# ------------------------------------------------------------
# 5. Python virtual environment
# ------------------------------------------------------------
echo "[5/11] Setting up Python virtual environment..."
cd "$APP_DIR" || {
    echo "ERROR: Failed to cd to $APP_DIR"
    exit 1
}
if [ ! -d "venv" ]; then
    python3 -m venv venv || {
        echo "ERROR: Failed to create virtual environment"
        exit 1
    }
    echo "[OK] Created venv"
fi

source venv/bin/activate

# ------------------------------------------------------------
# 6. Install Python dependencies
# ------------------------------------------------------------
echo "[6/11] Installing Python packages..."
pip install --upgrade pip
pip install flask

# ------------------------------------------------------------
# 7. Permissions for scripts
# ------------------------------------------------------------
echo "[7/11] Setting script permissions..."
SCRIPTS=(install.sh update.sh sync_cron.py update_play_alarm_path.py play_alarm.sh play_cron_sound.sh generate_ssl_cert.sh backup.sh restore.sh diagnostics.sh factory_reset.sh postinstall.sh list_alarms.sh uninstall.sh)
for script in "${SCRIPTS[@]}"; do
  if [ -f "$APP_DIR/$script" ]; then
    chmod +x "$APP_DIR/$script"
    echo "[OK] $script marked executable"
  fi
done

# ------------------------------------------------------------
# 8. Systemd services
# ------------------------------------------------------------
echo "[8/11] Installing systemd services..."

# Get user ID for XDG_RUNTIME_DIR
SERVICE_UID=$(id -u "$SERVICE_USER" 2>/dev/null || echo "1000")

sudo bash -c "cat > $SERVICE_FILE" <<EOF
[Unit]
Description=ChurchBell Web UI
After=network.target sound.target pipewire.service pipewire-pulse.service
Wants=pipewire.service pipewire-pulse.service

[Service]
User=$SERVICE_USER
WorkingDirectory=$APP_DIR
Environment="CHURCHBELL_ADMIN_USER=${ADMIN_USER}"
Environment="CHURCHBELL_ADMIN_PASS=${ADMIN_PASS}"
Environment="XDG_RUNTIME_DIR=/run/user/${SERVICE_UID}"
ExecStart=$APP_DIR/venv/bin/python app.py
Restart=always

[Install]
WantedBy=multi-user.target
EOF

sudo bash -c "cat > $HOME_SERVICE_FILE" <<EOF
[Unit]
Description=ChurchBell Home UI
After=network.target sound.target pipewire.service pipewire-pulse.service
Wants=pipewire.service pipewire-pulse.service

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
# 9. PipeWire audio setup (required for Pi3)
# ------------------------------------------------------------
echo "[9/11] Setting up PipeWire audio system..."
# Enable and start PipeWire services (may be user or system service)
if systemctl list-unit-files | grep -q "pipewire.service"; then
    sudo systemctl enable pipewire.service || true
    sudo systemctl start pipewire.service || true
fi
if systemctl list-unit-files | grep -q "pipewire-pulse.service"; then
    sudo systemctl enable pipewire-pulse.service || true
    sudo systemctl start pipewire-pulse.service || true
fi
# Also try user service (common on newer Pi OS) - use current user
CURRENT_USER="$(whoami)"
systemctl --user enable pipewire.service 2>/dev/null || true
systemctl --user start pipewire.service 2>/dev/null || true
systemctl --user enable pipewire-pulse.service 2>/dev/null || true
systemctl --user start pipewire-pulse.service 2>/dev/null || true

# Verify pw-play is available
if command -v pw-play &>/dev/null; then
    echo "[OK] pw-play (PipeWire) is available"
else
    echo "[WARN] pw-play not found - audio playback may not work"
fi

# ------------------------------------------------------------
# 10. SSL Certificate generation
# ------------------------------------------------------------
echo "[10/11] Generating SSL certificate for HTTPS..."
cd "$APP_DIR"
if [ -f "generate_ssl_cert.sh" ]; then
    bash generate_ssl_cert.sh || echo "[WARN] SSL certificate generation failed - HTTPS will not work"
else
    echo "[WARN] generate_ssl_cert.sh not found - HTTPS will not work"
fi

# ------------------------------------------------------------
# 11. Cron setup
# ------------------------------------------------------------
echo "[11/11] Ensuring cron is running..."
sudo systemctl enable cron
sudo systemctl start cron

echo "Syncing cron with current alarms..."
cd "$APP_DIR"
python3 sync_cron.py || true

echo "Updating play_alarm.sh with correct project path..."
python3 update_play_alarm_path.py || true

# ------------------------------------------------------------
# Done
# ------------------------------------------------------------
echo ""
echo "=== ChurchBell installation complete ==="
echo "Service is running on HTTPS port 8080"
echo "Visit: https://<your-pi-ip>:8080"
echo "HTTP port 80 redirects to HTTPS login"
echo ""

# Final ownership check (everything owned by current user)
CURRENT_USER="$(whoami)"
sudo chown -R "$CURRENT_USER":"$CURRENT_USER" "$APP_DIR" 2>/dev/null || true