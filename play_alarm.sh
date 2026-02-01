#!/bin/bash
# Scheduled alarm sound player
# Extracts filename from any path and plays from /home/pi/ChurchBell/sounds/
# NOTE: Uses pw-play (PipeWire). aplay (ALSA) is NOT supported in future Pi3 builds.

SOUNDS_DIR="/home/pi/ChurchBell/sounds"
SOUND_PATH="$1"

# Exit silently if no sound path provided
if [ -z "$SOUND_PATH" ]; then
  exit 0
fi

# Extract just the filename (basename) from the path
FILENAME=$(basename "$SOUND_PATH")
FULL_PATH="${SOUNDS_DIR}/${FILENAME}"

# Exit silently if file doesn't exist
if [ ! -f "$FULL_PATH" ]; then
  exit 0
fi

# Play the sound file
pw-play "$FULL_PATH" >/dev/null 2>&1
