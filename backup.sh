#!/bin/bash
set -euo pipefail

INSTALL_DIR="/opt/church-bells"
BACKUP_DIR="${INSTALL_DIR}/backups"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
BACKUP_FILE="${BACKUP_DIR}/churchbells-backup-${TIMESTAMP}.zip"
LATEST_FILE="${BACKUP_DIR}/churchbells-backup-latest.zip"

mkdir -p "$BACKUP_DIR"

# Export alarms
sqlite3 "${INSTALL_DIR}/churchbells.db" <<EOF
.output ${INSTALL_DIR}/alarms.json
.mode json
SELECT * FROM alarms;
EOF

# Create zip
zip -r "$BACKUP_FILE" "${INSTALL_DIR}/alarms.json" "${INSTALL_DIR}/sounds"

# Update symlink for "latest"
ln -sf "$BACKUP_FILE" "$LATEST_FILE"

echo "Backup created: $BACKUP_FILE"
