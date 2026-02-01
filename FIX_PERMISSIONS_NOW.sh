#!/bin/bash
# Quick fix for permission issues during install
# Run this if you get permission errors
# Note: Service user is now the same as the current user

APP_DIR="/home/pi/ChurchBell"
CURRENT_USER="$(whoami)"

echo "Fixing permissions for ChurchBell installation..."
echo "Using current user: $CURRENT_USER as service user"

# Fix APP_DIR permissions - owned by current user
sudo chmod 755 "$APP_DIR"
sudo chown -R "$CURRENT_USER":"$CURRENT_USER" "$APP_DIR"

# If venv exists but has wrong permissions
if [ -d "$APP_DIR/venv" ]; then
    sudo chown -R "$CURRENT_USER":"$CURRENT_USER" "$APP_DIR/venv"
    sudo chmod -R 755 "$APP_DIR/venv"
fi

# Ensure current user is in audio group
sudo usermod -aG audio "$CURRENT_USER" || true

echo "Permissions fixed. You can now continue with install.sh"
