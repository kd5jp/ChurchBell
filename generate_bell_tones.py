#!/usr/bin/env python3
"""
Generate 6 pleasing chime tones for a class bell system.
Creates WAV files with harmonic-rich chime sounds.
Includes user-preferred frequencies: 523.25Hz, 659.25Hz, 783.99Hz
"""

try:
    import numpy as np
except ImportError:
    print("ERROR: numpy is required. Install it with: pip install numpy")
    exit(1)

import wave
import os
from pathlib import Path

# Configuration
SAMPLE_RATE = 44100  # CD quality
DURATION = 2.0  # seconds
OUTPUT_DIR = Path(__file__).parent / "sounds"

def generate_bell_tone(fundamental_freq, duration=DURATION, sample_rate=SAMPLE_RATE):
    """
    Generate a bell-like tone with multiple harmonics and decay envelope.
    
    Bell tones typically have these characteristics:
    - Multiple harmonics (overtones)
    - Exponential decay (higher frequencies decay faster)
    - Slight frequency modulation for richness
    """
    t = np.linspace(0, duration, int(sample_rate * duration))
    
    # Fundamental frequency and harmonics
    # Bell tones have strong odd harmonics
    harmonics = [
        (1.0, fundamental_freq),      # Fundamental
        (0.5, fundamental_freq * 2), # Octave
        (0.3, fundamental_freq * 3), # Fifth
        (0.2, fundamental_freq * 4), # Octave
        (0.15, fundamental_freq * 5), # Third
        (0.1, fundamental_freq * 6),  # Fifth
        (0.05, fundamental_freq * 7),  # Seventh
    ]
    
    # Generate the waveform
    waveform = np.zeros_like(t)
    
    for amplitude, freq in harmonics:
        # Add slight frequency modulation for richness
        phase = 2 * np.pi * freq * t
        # Add subtle vibrato
        vibrato = 0.02 * np.sin(2 * np.pi * 5 * t)  # 5 Hz vibrato
        phase += vibrato
        
        # Exponential decay - higher harmonics decay faster
        decay_rate = 1.0 + (amplitude * 2)  # Higher harmonics decay faster
        envelope = np.exp(-decay_rate * t / duration)
        
        waveform += amplitude * np.sin(phase) * envelope
    
    # Normalize
    waveform = waveform / np.max(np.abs(waveform))
    
    # Apply overall envelope (attack and decay)
    attack_time = 0.05  # Quick attack
    attack_samples = int(attack_time * sample_rate)
    decay_samples = len(waveform) - attack_samples
    
    envelope = np.ones_like(waveform)
    # Attack (fade in)
    envelope[:attack_samples] = np.linspace(0, 1, attack_samples)
    # Decay (exponential fade out)
    decay_curve = np.exp(-3 * np.linspace(0, 1, decay_samples))
    envelope[attack_samples:] = decay_curve
    
    waveform = waveform * envelope
    
    # Normalize again after envelope
    if np.max(np.abs(waveform)) > 0:
        waveform = waveform / np.max(np.abs(waveform))
    
    return waveform

def save_wav(filename, waveform, sample_rate=SAMPLE_RATE):
    """Save waveform as WAV file"""
    # Convert to 16-bit PCM
    waveform_int = np.int16(waveform * 32767)
    
    with wave.open(str(filename), 'w') as wav_file:
        wav_file.setnchannels(1)  # Mono
        wav_file.setsampwidth(2)  # 16-bit
        wav_file.setframerate(sample_rate)
        wav_file.writeframes(waveform_int.tobytes())

def main():
    """Generate 6 bell tones"""
    # Ensure output directory exists
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    
    # Define 6 pleasing chime tones
    # Using musical intervals for harmony, including user-preferred frequencies
    bell_configs = [
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
    
    for config in bell_configs:
        print(f"Generating: {config['name']} ({config['description']})")
        print(f"  Frequency: {config['freq']:.2f} Hz")
        
        waveform = generate_bell_tone(config['freq'])
        output_path = OUTPUT_DIR / config['name']
        save_wav(output_path, waveform)
        
        print(f"  Saved to: {output_path}")
        print()
    
    print("✓ All chime tones generated successfully!")
    print(f"\nFiles are ready to use in the ChurchBell system.")
    print(f"Chimes are available in the sounds/ directory.")

if __name__ == "__main__":
    main()
