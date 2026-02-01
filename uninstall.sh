#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Detect project directory: use git root if available, otherwise script directory
# Still allows CHURCHBELL_APP_DIR override for flexibility
if [ -z "${CHURCHBELL_APP_DIR:-}" ]; then
    if command -v git >/dev/null 2>&1 && cd "$SCRIPT_DIR" && git rev-parse --show-toplevel >/dev/null 2>&1; then
        APP_DIR="$(cd "$SCRIPT_DIR" && git rev-parse --show-toplevel)"
    else
        APP_DIR="$SCRIPT_DIR"
    fi
else
    APP_DIR="$CHURCHBELL_APP_DIR"
fi
SERVICE_NAME="churchbell.service"
HOME_SERVICE_NAME="churchbell-home.service"

echo "This will remove the virtual environment, database, and systemd services."
echo "Your code and sound files will remain untouched."
read -p "Continue? [y/N] " ans

if [[ "$ans" != "y" && "$ans" != "Y" ]]; then
  echo "Aborted."
  exit 0
fi

echo "Stopping services..."
sudo systemctl stop "$HOME_SERVICE_NAME" 2>/dev/null || true
sudo systemctl stop "$SERVICE_NAME" 2>/dev/null || true

echo "Disabling services..."
sudo systemctl disable "$HOME_SERVICE_NAME" 2>/dev/null || true
sudo systemctl disable "$SERVICE_NAME" 2>/dev/null || true

echo "Removing systemd unit files..."
sudo rm -f /etc/systemd/system/churchbell-home.service
sudo rm -f /etc/systemd/system/churchbell.service

# Clean up systemd state
sudo systemctl daemon-reload
sudo systemctl reset-failed 2>/dev/null || true

echo "Removing virtual environment and database..."
rm -rf "$APP_DIR/venv"
rm -f "$APP_DIR/bells.db"

echo "Uninstall complete."
