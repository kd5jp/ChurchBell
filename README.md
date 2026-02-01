# ChurchBell System

A production-ready, appliance-grade bell scheduling system for Raspberry Pi with a modern web interface, role-based access control, and comprehensive backup capabilities.

## Overview

ChurchBell is a lightweight, reliable system for scheduling and playing bell chimes on a Raspberry Pi. It features a secure web interface, automatic alarm scheduling via cron, HTTPS support, and a modular architecture designed for easy maintenance and future expansion.

## Features

### 🔔 Bell Scheduling
- **Web-based scheduler** - Easy-to-use interface for managing alarms
- **Day and time selection** - Schedule alarms for any day of the week
- **Sound file management** - Upload, test, and manage WAV sound files
- **Enable/disable alarms** - Toggle alarms without deleting them
- **Volume control** - System-wide volume control with persistent settings
- **Automatic playback** - Reliable cron-based alarm execution using PipeWire

### 🔐 Security & Access Control
- **HTTPS support** - Secure communication with self-signed SSL certificates
- **Role-based access control (RBAC)** - Administrator and user roles with granular permissions
- **Permission system** - Control access to bells, backup/restore, and user management
- **Session management** - Secure login system with session cookies
- **Password management** - Change passwords through the web interface

### 💾 Backup & Restore
- **Full system backups** - Backup alarms and sound files with one click
- **Download backups** - Download backup files directly from the web interface
- **Restore functionality** - Upload and restore backups through the web interface
- **Backup management** - View, download, and delete existing backups

### 🎵 Audio System
- **PipeWire integration** - Modern audio system support for Raspberry Pi
- **Default chime** - Automatically generated pleasant C5-E5-G5 major triad chime
- **Custom sounds** - Upload your own WAV files for personalized alarms
- **Test playback** - Test sounds before scheduling

### 🛠️ System Management
- **Systemd services** - Reliable service management with automatic startup
- **Service user** - Dedicated user account for secure operation
- **Database** - SQLite database for reliable data storage
- **Cron integration** - Automatic alarm scheduling via system crontab

## Requirements

- **Hardware**: Raspberry Pi (any model with audio output)
- **OS**: Raspberry Pi OS or Debian-based Linux
- **Python**: Python 3.9 or higher
- **Audio**: Audio output configured (HDMI or 3.5mm jack)
- **Network**: Internet connection for initial installation

## Installation

### Quick Install

1. Clone the repository:
```bash
git clone https://github.com/kd5jp/ChurchBell.git
cd ChurchBell
```

2. Run the installer:
```bash
./install.sh
```

The installer will:
- Install all system dependencies
- Create a Python virtual environment
- Set up systemd services
- Generate SSL certificates for HTTPS
- Create default chime sound
- Initialize the database
- Start the services

### Custom Installation

You can customize the installation with environment variables:

```bash
CHURCHBELL_SERVICE_USER=churchbells \
CHURCHBELL_APP_DIR=/opt/churchbell \
CHURCHBELL_ADMIN_USER=admin \
CHURCHBELL_ADMIN_PASS=yourpassword \
./install.sh
```

**Environment Variables:**
- `CHURCHBELL_SERVICE_USER` - User account for running services (default: current user)
- `CHURCHBELL_APP_DIR` - Installation directory (default: `$HOME/ChurchBell`)
- `CHURCHBELL_ADMIN_USER` - Initial admin username (default: `admin`)
- `CHURCHBELL_ADMIN_PASS` - Initial admin password (default: `changeme`)

### Post-Installation

After installation, access the system:

- **Web Interface**: `https://<pi-ip>:8080` (HTTPS) or `http://<pi-ip>:8080` (HTTP fallback)
- **Home Page**: `http://<pi-ip>` (redirects to HTTPS login)
- **Default Login**: 
  - Username: `admin`
  - Password: `changeme` (change immediately!)

## Usage

### Bell Scheduler

1. Log in to the web interface
2. Navigate to **Bell Scheduler** from the dashboard
3. Click **Add Alarm** to create a new schedule
4. Select day, time, and sound file
5. Enable or disable the alarm as needed
6. Alarms will play automatically at the scheduled times

### User Management

**Administrators** can:
- Create new users with custom roles
- Assign permissions (bells, backup, users, etc.)
- Change user roles (admin/user)
- Delete users
- Manage all permissions

**Regular Users** can:
- Change their own password
- Access features based on assigned permissions

### Backup & Restore

1. Navigate to **Backup & Restore** from the dashboard
2. Click **Create Backup** to generate a new backup
3. Download backups using the **Download** button
4. Upload backups using the **Restore from Backup** form
5. Delete old backups as needed

**Note**: Restoring a backup will replace all current alarms and sound files.

### Sound Management

1. Upload WAV files through the **Sound Files** section
2. Test sounds before scheduling
3. Delete unused sound files
4. Use the default `chime.wav` or upload custom sounds

## Updating

To update the application:

```bash
cd /path/to/ChurchBell
./update.sh
```

This will:
- Pull the latest code from git
- Update Python dependencies
- Restart services automatically

## Uninstalling

To remove the system:

```bash
cd /path/to/ChurchBell
./uninstall.sh
```

This will:
- Stop and disable systemd services
- Remove service files
- Delete the virtual environment
- Delete the database

**Note**: Your source code and sound files will remain intact.

## Project Structure

```
ChurchBell/
├── app.py                    # Main Flask application (port 8080)
├── home.py                   # Home page redirect service (port 80)
├── sync_cron.py              # Cron synchronization script
├── generate_chime.py         # Default chime generator
├── generate_ssl_cert.sh      # SSL certificate generator
├── cleanup_ssl_certs.sh      # SSL certificate cleanup utility
├── factory_reset.sh          # Factory reset utility
├── install.sh                # Installation script
├── update.sh                 # Update script
├── uninstall.sh              # Uninstallation script
├── play_cron_sound.sh        # Cron sound playback script
├── play_alarm.sh             # Alarm playback script
├── list_alarms.sh            # List alarms utility
├── requirements.txt           # Python dependencies
├── bells.db                  # SQLite database (auto-created)
├── sounds/                   # Sound files directory
│   └── chime.wav            # Default chime (auto-generated)
├── backups/                  # Backup files directory
├── ssl/                      # SSL certificates directory
├── templates/                # HTML templates
│   ├── base.html
│   ├── login.html
│   ├── dashboard.html
│   ├── alarms.html
│   ├── users.html
│   └── backup.html
└── static/                   # Static files
    └── main.css
```

## Permissions System

The system uses a role-based access control (RBAC) system:

### Roles
- **Administrator** - Full system access, all permissions
- **User** - Custom permissions assigned by administrators

### Available Permissions
- `bells` - Access to bell scheduler and alarm management
- `backup` - Access to backup and restore functionality
- `users` - Access to user management
- `tts` - Text-to-speech (reserved for future)
- `announcements` - Live announcements (reserved for future)

Administrators automatically have all permissions. Regular users can be assigned specific permissions as needed.

## Security

### HTTPS
- Self-signed SSL certificates generated during installation
- HTTPS on port 8080 for secure web interface
- HTTP on port 80 redirects to HTTPS login
- Certificates can be regenerated using `generate_ssl_cert.sh`

### Authentication
- Session-based authentication
- Secure cookies (HTTPS only)
- Password management through web interface
- Role-based access control

### Best Practices
- Change default admin password immediately
- Use strong passwords for all users
- Regularly create backups
- Keep the system updated

## Troubleshooting

### Services Not Starting
```bash
sudo systemctl status churchbell.service
sudo systemctl status churchbell-home.service
sudo journalctl -u churchbell.service -n 50
```

### Audio Issues
- Ensure PipeWire is running: `systemctl --user status pipewire`
- Check audio output: `pw-play /path/to/sound.wav`
- Verify user is in audio group: `groups`

### SSL Certificate Issues
```bash
cd /path/to/ChurchBell
./cleanup_ssl_certs.sh
./generate_ssl_cert.sh
sudo systemctl restart churchbell.service churchbell-home.service
```

### Reset to Factory Defaults
```bash
cd /path/to/ChurchBell
./factory_reset.sh
```

Use `--purge` flag to also remove sound files and backups:
```bash
./factory_reset.sh --purge
```

## Development

### Adding New Features
The system is designed for modular expansion. New features can be added as:
- New Flask routes in `app.py`
- New systemd services for independent functionality
- New permission types in the RBAC system

### Database Schema
The SQLite database (`bells.db`) contains:
- `users` - User accounts with roles
- `user_permissions` - User permission assignments
- `alarms` - Scheduled alarms
- `settings` - System settings (volume, etc.)

## License

See [LICENSE](LICENSE) file for details.

## Author

Created by Jesse (KD5JP)

Designed for reliability, simplicity, and long-term maintainability.

## Support

For issues, feature requests, or contributions, please visit the project repository:
https://github.com/kd5jp/ChurchBell

---

**Version**: 3.0  
**Status**: Production Ready
