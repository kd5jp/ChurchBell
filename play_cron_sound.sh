#!/bin/bash

export XDG_RUNTIME_DIR=/run/user/1000

LOGFILE="/home/pi/ChurchBell/cron_alarm.log"
PWPLAY="/usr/bin/pw-play"

SOUND="$1"

if [ -z "$SOUND" ]; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') - ERROR: No sound file provided" >> "$LOGFILE"
    exit 1
fi

echo "$(date '+%Y-%m-%d %H:%M:%S') - Playing: $SOUND" >> "$LOGFILE"

"$PWPLAY" "$SOUND" >> "$LOGFILE" 2>&1
