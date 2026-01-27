#!/bin/bash
sqlite3 bells.db <<EOF
.headers on
.mode column
SELECT id, day_of_week, time_str, sound_path, enabled
FROM alarms
ORDER BY day_of_week, time_str;
EOF
