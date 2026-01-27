#!/usr/bin/env bash
set -e

APP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "This will remove the virtual environment, database, and systemd services."
echo "Your code and sound files will remain untouched."
read -p "Continue? [y/N] " ans

if [[ "$ans" != "y" && "$ans" != "Y" ]]; then
  echo "Aborted."
  exit 0
fi

echo "Stopping services..."
sudo systemctl stop churchbells-home.service || true
sudo systemctl stop churchbells.service || true

echo "Disabling services..."
sudo systemctl disable churchbells-home.service || true
sudo systemctl disable churchbells.service || true

echo "Removing systemd unit files..."
sudo rm -f /etc/systemd/system/churchbells-home.service
sudo rm -f /etc/systemd/system/churchbells.service
sudo systemctl daemon-reload

echo "Removing virtual environment and database..."
rm -rf "$APP_DIR/venv"
rm -f "$APP_DIR/bells.db"

echo "Uninstall complete."
