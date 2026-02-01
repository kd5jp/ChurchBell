#!/bin/bash
# Generate default chime.wav sound file
# Uses sox if available, otherwise Python fallback

OUTPUT_DIR="${1:-sounds}"
OUTPUT_FILE="${OUTPUT_DIR}/chime.wav"

# Create output directory if it doesn't exist
mkdir -p "$OUTPUT_DIR"

echo "Generating chime.wav..."

# Method 1: Try using sox (most common on Linux)
if command -v sox &>/dev/null; then
    echo "Using sox to generate chime..."
    # Generate a pleasant bell chime: multiple tones with fade
    sox -n "$OUTPUT_FILE" \
        synth 0.3 sine 523.25 \
        synth 0.3 sine 659.25 \
        synth 0.3 sine 783.99 \
        fade 0.1 0.3 0.1 \
        rate 44100
    echo "✓ Chime generated using sox"
    exit 0
fi

# Method 2: Try using Python script (preferred - uses standard library)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/generate_chime.py" ] && command -v python3 &>/dev/null; then
    echo "Using Python script to generate chime..."
    python3 "$SCRIPT_DIR/generate_chime.py" "$OUTPUT_FILE"
    
    if [ -f "$OUTPUT_FILE" ]; then
        echo "✓ Chime generated using Python"
        exit 0
    fi
fi

# Method 3: Fallback - create empty file or copy from template
echo "Warning: Neither sox nor Python available. Creating placeholder..."
echo "Please install sox: sudo apt install sox"
echo "Or upload your own chime.wav file to $OUTPUT_DIR/"

# Create a minimal valid WAV file (silence)
cat > "$OUTPUT_FILE" << 'WAV_HEADER'
RIFF    WAVEfmt 
WAV_HEADER

echo "Placeholder file created. Please replace with actual chime.wav"
