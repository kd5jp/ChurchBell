#!/usr/bin/env bash
set -e

APP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Installing ChurchBell..."

sudo apt-get update
sudo apt install -y \
    python3 python3-pip python3-venv \
    git cron sqlite3 libsqlite3-dev \
    alsa-utils \
    dos2unix


# Ensure pi owns the app directory
sudo chown -R pi:pi "$APP_DIR"

cd "$APP_DIR"

# Python venv
if [ ! -d venv ]; then
  python3 -m venv venv
fi

source venv/bin/activate
pip install --upgrade pip
pip install flask

# Create sounds dir and built-in chime
mkdir -p "$APP_DIR/sounds"
if [ ! -f "$APP_DIR/sounds/chime.wav" ]; then
  echo "Creating default chime sound..."
  sox -n "$APP_DIR/sounds/chime.wav" synth 1 sine 880
fi

# First run to initialize DB
echo "Initializing database..."
python3 - <<EOF
from app import init_db
init_db()
EOF

echo "Creating systemd services..."

# Home page on port 80
sudo bash -c "cat > /etc/systemd/system/churchbells-home.service" <<EOF
[Unit]
Description=Church Bells Home Page
After=network.target

[Service]
Type=simple
WorkingDirectory=$APP_DIR
ExecStart=$APP_DIR/venv/bin/python3 $APP_DIR/home.py
Restart=always
User=pi
Environment="PYTHONUNBUFFERED=1"
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

# Bell scheduler on port 8080
sudo bash -c "cat > /etc/systemd/system/churchbells.service" <<EOF

[Unit]
Description=Church Bells Scheduler
After=network.target sound.target

[Service]
chmod +x "$APP_DIR/sync_cron.py"
chmod +x "$APP_DIR/play_alarm.sh"
Type=simple
WorkingDirectory=$APP_DIR
ExecStart=$APP_DIR/venv/bin/python3 $APP_DIR/app.py
Restart=always
User=pi
Environment="PYTHONUNBUFFERED=1"
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable churchbells-home.service
sudo systemctl enable churchbells.service
sudo systemctl start churchbells-home.service
sudo systemctl start churchbells.service

echo "Install complete."
echo "Services installed and started."
echo "Home Page:      http://<pi-ip>/"
echo "Bell Scheduler: http://<pi-ip>:8080"
