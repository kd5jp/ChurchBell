#!/bin/bash

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
sqlite3 "$APP_DIR/bells.db" <<EOF
.headers on
.mode column
SELECT id, day_of_week, time_str, sound_path, enabled
FROM alarms
ORDER BY day_of_week, time_str;
EOF
