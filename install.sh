#!/usr/bin/env bash
set -e

APP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Installing ChurchBellsSystem..."

sudo apt-get update
sudo apt-get install -y python3 python3-venv python3-pip alsa-utils sox

if ! id "churchbell" &>/dev/null; then
    sudo useradd -r -s /usr/sbin/nologin churchbell
fi
sudo chown -R churchbell:churchbell "$APP_DIR"

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
from app import init_db, start_scheduler
init_db()
EOF

echo "Install complete."
echo "Run with: source venv/bin/activate && python3 app.py"
echo "Creating systemd services..."

sudo bash -c "cat >/etc/systemd/system/churchbells-home.service" <<EOF
[Unit]
Description=Church Bells Home Page
After=network.target

[Service]
WorkingDirectory=$APP_DIR
ExecStart=$APP_DIR/venv/bin/python3 $APP_DIR/home.py
Restart=always
User=churchbell

[Install]
WantedBy=multi-user.target
EOF

sudo bash -c "cat >/etc/systemd/system/churchbells.service" <<EOF
[Unit]
Description=Church Bells Scheduler
After=network.target sound.target

[Service]
WorkingDirectory=$APP_DIR
ExecStart=$APP_DIR/venv/bin/python3 $APP_DIR/app.py
Restart=always
User=churchbell

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable churchbells-home.service
sudo systemctl enable churchbells.service
sudo systemctl start churchbells-home.service
sudo systemctl start churchbells.service

echo "Services installed and started."
