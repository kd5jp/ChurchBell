#!/usr/bin/env python3
"""
Generate 6 pleasing chime tones for a class bell system.
Uses sox for natural-sounding chimes when available, Python fallback otherwise.
Creates WAV files with natural bell-like sounds.
"""

import subprocess
import sys
import os
from pathlib import Path

# Configuration
SAMPLE_RATE = 44100  # CD quality
OUTPUT_DIR = Path(__file__).resolve().parent / "sounds"

def generate_chime_sox(freq, output_file, duration=0.5):
    """
    Generate a chime using sox - produces natural, clean sound.
    Uses sequential tones similar to the original generate_chime.sh approach.
    """
    # Create a sequence of tones: fundamental, fifth, and octave
    # This creates a natural bell-like chime sound
    # Using shorter durations for each tone creates a pleasant sequence
    tone_duration = duration / 3
    
    cmd = [
        "sox", "-n", str(output_file),
        "synth", str(tone_duration), "sine", str(freq),           # Fundamental
        "synth", str(tone_duration), "sine", str(freq * 1.5),     # Perfect fifth
        "synth", str(tone_duration), "sine", str(freq * 2),        # Octave
        "fade", "0.05", str(duration * 0.4), "0.1",
        "rate", str(SAMPLE_RATE)
    ]
    
    try:
        result = subprocess.run(cmd, check=True, capture_output=True, text=True)
        return True
    except (subprocess.CalledProcessError, FileNotFoundError):
        return False

def generate_chime_python(freq, output_file, duration=0.5, sample_rate=SAMPLE_RATE):
    """
    Python fallback - simpler, more natural sound without complex harmonics.
    Uses basic sine waves with natural decay.
    """
    try:
        import numpy as np
        import wave
    except ImportError:
        print("ERROR: numpy is required for Python fallback. Install it with: pip install numpy")
        return False
    
    t = np.linspace(0, duration, int(sample_rate * duration))
    
    # Simple, natural chime: fundamental + octave + fifth
    # Less complex than before - more natural sounding
    waveform = (
        0.6 * np.sin(2 * np.pi * freq * t) +           # Fundamental
        0.3 * np.sin(2 * np.pi * freq * 1.5 * t) +    # Perfect fifth
        0.2 * np.sin(2 * np.pi * freq * 2 * t)        # Octave
    )
    
    # Natural exponential decay
    decay = np.exp(-2.5 * t / duration)
    waveform = waveform * decay
    
    # Simple fade in/out
    fade_samples = int(0.05 * sample_rate)
    fade_in = np.linspace(0, 1, fade_samples)
    fade_out = np.linspace(1, 0, fade_samples)
    
    waveform[:fade_samples] *= fade_in
    waveform[-fade_samples:] *= fade_out
    
    # Normalize
    if np.max(np.abs(waveform)) > 0:
        waveform = waveform / np.max(np.abs(waveform))
    
    # Convert to 16-bit PCM
    waveform_int = np.int16(waveform * 32767)
    
    # Save as WAV
    try:
        with wave.open(str(output_file), 'w') as wav_file:
            wav_file.setnchannels(1)  # Mono
            wav_file.setsampwidth(2)  # 16-bit
            wav_file.setframerate(sample_rate)
            wav_file.writeframes(waveform_int.tobytes())
        return True
    except Exception as e:
        print(f"ERROR: Failed to save WAV file: {e}")
        return False

def generate_chime(freq, output_file, description):
    """Generate a chime using the best available method"""
    print(f"Generating: {output_file.name} ({description})")
    print(f"  Frequency: {freq:.2f} Hz")
    
    # Try sox first (produces more natural sound)
    if generate_chime_sox(freq, output_file):
        print(f"  ✓ Generated using sox (natural sound)")
        return True
    
    # Fallback to Python
    print(f"  Using Python fallback...")
    if generate_chime_python(freq, output_file):
        print(f"  ✓ Generated using Python")
        return True
    
    print(f"  ✗ Failed to generate chime")
    return False

def main():
    """Generate 6 chime tones"""
    # Ensure output directory exists
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    
    # Check if sox is available
    sox_available = False
    try:
        result = subprocess.run(
            ["sox", "--version"],
            capture_output=True,
            text=True,
            timeout=2
        )
        sox_available = result.returncode == 0
    except (FileNotFoundError, subprocess.TimeoutExpired):
        sox_available = False
    
    if sox_available:
        print("Using sox for natural-sounding chimes (recommended)")
    else:
        print("sox not found - using Python fallback")
        print("For best results, install sox: sudo apt install sox")
    print()
    
    # Define 6 pleasing chime tones
    # Using user-preferred frequencies for natural sound
    chime_configs = [
        {
            "name": "chime1.wav",
            "freq": 523.25,  # C5 - bright and clear (user preferred)
            "description": "Chime 1 - C5"
        },
        {
            "name": "chime2.wav",
            "freq": 659.25,  # E5 - cheerful (user preferred)
            "description": "Chime 2 - E5"
        },
        {
            "name": "chime3.wav",
            "freq": 783.99,  # G5 - warm and pleasant (user preferred)
            "description": "Chime 3 - G5"
        },
        {
            "name": "chime4.wav",
            "freq": 440.00,  # A4 - standard reference tone
            "description": "Chime 4 - A4"
        },
        {
            "name": "chime5.wav",
            "freq": 587.33,  # D5 - attention-getting
            "description": "Chime 5 - D5"
        },
        {
            "name": "chime6.wav",
            "freq": 493.88,  # B4 - clear and pleasant
            "description": "Chime 6 - B4"
        },
    ]
    
    print("Generating chime tones...")
    print(f"Output directory: {OUTPUT_DIR}")
    print()
    
    success_count = 0
    for config in chime_configs:
        output_path = OUTPUT_DIR / config['name']
        if generate_chime(config['freq'], output_path, config['description']):
            success_count += 1
        print()
    
    if success_count == len(chime_configs):
        print("✓ All chime tones generated successfully!")
        print(f"\nChimes are available in: {OUTPUT_DIR}")
        print("Ready to use in the ChurchBell system.")
    else:
        print(f"⚠ Generated {success_count}/{len(chime_configs)} chimes")
        if not sox_available:
            print("\nTip: Install sox for better sound quality:")
            print("  sudo apt install sox")

if __name__ == "__main__":
    main()
