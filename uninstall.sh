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

echo "=== ChurchBell Uninstaller ==="
echo "This will remove:"
echo "  - Virtual environment (venv/)"
echo "  - Database (bells.db)"
echo "  - Systemd services (churchbell.service, churchbell-home.service)"
echo ""
echo "Your code, sound files, and backups will remain untouched."
echo "Note: Services run as current user (no separate service user to remove)."
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
if [ -d "$APP_DIR/venv" ]; then
    rm -rf "$APP_DIR/venv"
    echo "  ✓ Removed venv/"
fi
if [ -f "$APP_DIR/bells.db" ]; then
    rm -f "$APP_DIR/bells.db"
    echo "  ✓ Removed bells.db"
fi

# Clean up cron jobs (if any)
echo "Cleaning up cron jobs..."
crontab -l 2>/dev/null | grep -v "ChurchBell" | crontab - 2>/dev/null || true
echo "  ✓ Removed cron jobs"

echo ""
echo "=== Uninstall complete ==="
echo "Services stopped and removed."
echo "Virtual environment and database deleted."
echo "Code and sound files remain in: $APP_DIR"
