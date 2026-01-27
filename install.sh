#!/usr/bin/env bash
set -e

APP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Installing ChurchBellsSystem..."

sudo apt-get update
sudo apt-get install -y python3 python3-venv python3-pip alsa-utils sox

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
