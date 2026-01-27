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
sudo systemctl stop churchbells-home.service 2>/dev/null || true
sudo systemctl stop churchbells.service 2>/dev/null || true

echo "Disabling services..."
sudo systemctl disable churchbells-home.service 2>/dev/null || true
sudo systemctl disable churchbells.service 2>/dev/null || true

echo "Removing systemd unit files..."
sudo rm -f /etc/systemd/system/churchbells-home.service
sudo rm -f /etc/systemd/system/churchbells.service

# Clean up systemd state
sudo systemctl daemon-reload
sudo systemctl reset-failed 2>/dev/null || true

echo "Removing virtual environment and database..."
rm -rf "$APP_DIR/venv"
rm -f "$APP_DIR/bells.db"

echo "Uninstall complete."
