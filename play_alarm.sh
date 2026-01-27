#!/bin/bash
APP_DIR="/home/pi/ChurchBell"
SOUND_PATH="$1"

if [ -z "$SOUND_PATH" ]; then
  exit 0
fi

FULL_PATH="${APP_DIR}/${SOUND_PATH}"

if [ ! -f "$FULL_PATH" ]; then
  exit 0
fi

/usr/bin/aplay "$FULL_PATH" >/dev/null 2>&1
