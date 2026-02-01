#!/usr/bin/env python3
"""
Generate default chime.wav sound file
Creates a pleasant bell chime using Python standard library only
"""
import wave
import struct
import math
import sys
from pathlib import Path

def generate_chime(output_path):
    """Generate a pleasant bell chime sound"""
    # Audio parameters
    sample_rate = 44100
    duration = 1.0  # seconds
    num_samples = int(sample_rate * duration)
    
    # Generate a pleasant chime: C5, E5, G5 chord (major triad)
    frequencies = [523.25, 659.25, 783.99]  # C5, E5, G5 in Hz
    amplitudes = [0.3, 0.25, 0.2]  # Decreasing volume for each tone
    
    # Create audio data
    audio_data = []
    for i in range(num_samples):
        t = float(i) / sample_rate
        sample = 0.0
        
        # Add each frequency with envelope (exponential decay)
        for freq, amp in zip(frequencies, amplitudes):
            envelope = math.exp(-t * 2.0)  # Exponential decay for natural sound
            sample += amp * envelope * math.sin(2.0 * math.pi * freq * t)
        
        # Normalize and convert to 16-bit integer
        sample = max(-1.0, min(1.0, sample))
        audio_data.append(int(sample * 32767.0))
    
    # Ensure output directory exists
    output_path = Path(output_path)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    
    # Write WAV file
    with wave.open(str(output_path), 'w') as wav_file:
        wav_file.setnchannels(1)  # Mono
        wav_file.setsampwidth(2)  # 16-bit
        wav_file.setframerate(sample_rate)
        wav_file.setcomptype('NONE', 'not compressed')
        
        for sample in audio_data:
            wav_file.writeframes(struct.pack('<h', sample))
    
    print(f"✓ Chime generated: {output_path}")
    print(f"  Duration: {duration}s, Sample rate: {sample_rate}Hz")
    print(f"  Frequencies: {', '.join([f'{f:.2f}Hz' for f in frequencies])}")

if __name__ == "__main__":
    # Default output path
    output_file = sys.argv[1] if len(sys.argv) > 1 else "sounds/chime.wav"
    generate_chime(output_file)
