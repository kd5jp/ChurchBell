# New Clean Architecture

## Overview

Clean, simple design with clear navigation and professional appearance.

## Flow

1. **Port 80** → Redirects to Port 8080 login
2. **Port 8080 /login** → Login page (SQLite auth)
3. **Port 8080 /** → Dashboard (read-only, after login)
4. **Port 8080 /alarms** → Bell Scheduler (full management)
5. **Port 8080 /users** → User Management (add/delete users, change password)

## Pages

### Login Page (`/login`)
- Simple login form
- Authenticates against SQLite `users` table
- Redirects to dashboard after login

### Dashboard (`/`)
- Read-only status page
- Shows:
  - Quick links to Bell Scheduler and User Management
  - System status (logged in user, alarm counts)
- Navigation bar at top

### Bell Scheduler (`/alarms`)
- View all alarms (read-only table)
- Add new alarm
- Toggle/Delete alarms
- Upload/Delete/Test sound files
- Volume control
- "Back to Dashboard" button

### User Management (`/users`)
- List all users
- Add new user
- Delete user (can't delete yourself)
- Change your password
- "Back to Dashboard" button

## Navigation

Top navigation bar (when logged in):
- Dashboard
- Bell Scheduler
- User Management
- Logout

## Database

All data stored in SQLite (`bells.db`):
- `users` table - authentication
- `alarms` table - scheduled alarms
- `settings` table - system settings

## Design

- Clean Bootstrap 5 styling
- Simple, professional appearance
- No fancy gradients or complex layouts
- Focus on functionality
- Clear navigation between pages

## Files

- `templates/base.html` - Base template with navigation
- `templates/login.html` - Login page
- `templates/dashboard.html` - Dashboard (read-only)
- `templates/alarms.html` - Bell Scheduler
- `templates/users.html` - User Management
- `app.py` - Main Flask app (port 8080)
- `home.py` - Redirect service (port 80)

## Routes

### Port 80 (home.py)
- `/` → Redirects to `http://<host>:8080/login`

### Port 8080 (app.py)
- `/login` → Login page
- `/logout` → Logout
- `/` → Dashboard (requires login)
- `/alarms` → Bell Scheduler (requires login)
- `/users` → User Management (requires login)
- `/add_user` → Add user (POST, requires login)
- `/delete_user/<id>` → Delete user (requires login)
- `/change_password` → Change password (POST, requires login)
- `/add_alarm` → Add alarm (POST, requires login)
- `/toggle_alarm/<id>` → Toggle alarm (requires login)
- `/delete_alarm/<id>` → Delete alarm (requires login)
- `/upload_sound` → Upload sound (POST, requires login)
- `/delete_sound/<filename>` → Delete sound (requires login)
- `/test_sound/<filename>` → Test sound (requires login)
- `/set_volume` → Set volume (POST, requires login)

## Security

- All routes except `/login` require authentication
- Users stored in SQLite database
- Session-based authentication
- Can't delete your own user account
