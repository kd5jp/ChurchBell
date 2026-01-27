#!/usr/bin/env bash
set -e

APP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$APP_DIR"

echo "Updating ChurchBellsSystem code (no DB changes)..."

# Here you might: git pull, reinstall deps, etc.
# For now, just reinstall requirements in case app.py changed imports.

if [ -d venv ]; then
  source venv/bin/activate
  pip install --upgrade pip
  pip install flask
fi

echo "Update complete. Restart your service or app.py if running."
