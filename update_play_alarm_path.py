#!/usr/bin/env python3
"""
Update play_alarm.sh with the correct project directory path.
Detects the actual project location (from git root or script directory)
and updates the SOUNDS_DIR path to point to the project's sounds directory.
Works regardless of where the project is installed (home directory, /opt, etc.).
"""
import os
import re
import subprocess
from pathlib import Path

def get_project_dir():
    """Detect the project directory using git or script location."""
    script_dir = Path(__file__).resolve().parent
    
    # Try to get git root first (most accurate)
    try:
        result = subprocess.run(
            ["git", "rev-parse", "--show-toplevel"],
            cwd=script_dir,
            capture_output=True,
            text=True,
            check=True
        )
        git_root = Path(result.stdout.strip())
        return git_root
    except (subprocess.CalledProcessError, FileNotFoundError):
        # Fall back to script directory
        return script_dir

def update_play_alarm_script(project_dir, play_alarm_path=None):
    """Update play_alarm.sh with the correct SOUNDS_DIR path based on actual project location."""
    if play_alarm_path is None:
        play_alarm_path = project_dir / "play_alarm.sh"
    else:
        play_alarm_path = Path(play_alarm_path)
    
    if not play_alarm_path.exists():
        print(f"[WARN] play_alarm.sh not found at {play_alarm_path}")
        return False
    
    # Read the current file
    with open(play_alarm_path, 'r') as f:
        content = f.read()
    
    # Determine the correct sounds directory path from actual project location
    # Use the actual project directory path, not a constructed home-based path
    sounds_dir = str(project_dir / "sounds")
    
    # Pattern to match: SOUNDS_DIR="/home/pi/ChurchBell/sounds" or similar
    pattern = r'SOUNDS_DIR="[^"]*"'
    replacement = f'SOUNDS_DIR="{sounds_dir}"'
    
    # Check if update is needed
    if re.search(pattern, content):
        new_content = re.sub(pattern, replacement, content)
        
        # Only write if content changed
        if new_content != content:
            with open(play_alarm_path, 'w') as f:
                f.write(new_content)
            print(f"[OK] Updated play_alarm.sh: SOUNDS_DIR=\"{sounds_dir}\"")
            return True
        else:
            print(f"[INFO] play_alarm.sh already has correct path: {sounds_dir}")
            return True
    else:
        print(f"[WARN] Could not find SOUNDS_DIR pattern in play_alarm.sh")
        return False

def main():
    """Main entry point."""
    project_dir = get_project_dir()
    project_name = project_dir.name
    
    print(f"[INFO] Detected project directory: {project_dir}")
    print(f"[INFO] Project name: {project_name}")
    print(f"[INFO] Sounds directory path: {project_dir / 'sounds'}")
    
    success = update_play_alarm_script(project_dir)
    
    if success:
        return 0
    else:
        return 1

if __name__ == "__main__":
    exit(main())
