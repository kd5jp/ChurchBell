#!/usr/bin/env bash
set -e

APP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$APP_DIR"

echo "This will remove venv and bells.db, but leave sounds/ and code."
read -p "Continue? [y/N] " ans
if [[ "$ans" != "y" && "$ans" != "Y" ]]; then
  echo "Aborted."
  exit 0
fi

rm -rf venv
rm -f bells.db

echo "Uninstall partial cleanup complete."
