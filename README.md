# 📚 Hytale Server Management Script - Documentation

## 📋 Table of Contents

- [Overview](#overview)
- [Prerequisites](#prerequisites)
- [Installation](#installation)
- [File Structure](#file-structure)
- [Configuration](#configuration)
- [Available Commands](#available-commands)
- [Usage Examples](#usage-examples)
- [Mod Management](#mod-management)
- [Backups](#backups)
- [Troubleshooting](#troubleshooting)

---

## 🎯 Overview

This Bash script provides automated management for a Hytale server with the following features:

- ✅ Automatic server installation
- ✅ Start/Stop/Restart operations
- ✅ AOT (Ahead-Of-Time) mode for faster startup
- ✅ Automatic updates
- ✅ Backup management
- ✅ Mod extraction and display
- ✅ External configuration
- ✅ Log management

---

## 🔧 Prerequisites

### Operating System
- Linux (tested on Debian/Ubuntu)
- Bash 4.0+

### Required Dependencies
```bash
# Install dependencies
apt-get update
apt-get install -y unzip java wget jq
```

**Dependency details:**
- `unzip`: Archive extraction
- `java`: Hytale server execution
- `wget` or `curl`: File downloads
- `jq`: JSON parsing (optional but recommended for mod display)

### Hytale Account
- A valid Hytale account for OAuth2 authentication

---

## 📥 Installation

### 1. Download the Script

```bash
# Create server directory
mkdir -p /root/hytale
cd /root/hytale

# Download the script (or copy it)
chmod +x manage-hytale-server.sh
```

### 2. First Installation

```bash
./manage-hytale-server.sh install
```

This command will:
1. Check dependencies
2. Download `hytale-downloader`
3. Prompt for OAuth2 authentication
4. Download the Hytale server
5. Extract and configure files

### 3. OAuth2 Authentication

During first installation, you'll see:

```
[WARNING] First use - OAuth2 authentication required

═══════════════════════════════════════════════════════════════
  OAUTH2 AUTHENTICATION
═══════════════════════════════════════════════════════════════

Procedure:
  1. Open the URL in your browser
  2. Log in with your Hytale account
  3. Enter the displayed code
  4. Download will start automatically
```

**Important:** Credentials are saved in `Config/.hytale-downloader-credentials.json` and won't be requested again.

---

## 📁 File Structure

```
/root/hytale/
├── manage-hytale-server.sh          # Main script
├── Config/                           # Configuration
│   ├── server.conf                   # Script configuration
│   └── .hytale-downloader-credentials.json  # OAuth2 credentials
├── Download/                         # Downloads
│   └── hytale-downloader             # Downloader binary
├── Server/                           # Hytale server
│   ├── HytaleServer.jar              # Main server
│   ├── HytaleServer.aot              # AOT cache
│   ├── Assets.zip                    # Game assets
│   ├── auth.enc                      # Authentication
│   ├── config.json                   # Server configuration
│   ├── bans.json                     # Ban list
│   ├── permissions.json              # Permissions
│   ├── whitelist.json                # Whitelist
│   ├── mods/                         # Installed mods
│   └── universe/                     # Server world
├── Logs/                             # Server logs
│   └── server.log                    # Main log file
├── Mods-Manifest/                    # Mod manifests
│   ├── *.json                        # Individual manifests
│   └── mods_summary.txt              # Mod summary
└── Backups/                          # Backups
    ├── initial_backup.tar.gz         # Initial backup (credentials)
    └── server_backup_*.tar.gz        # Regular backups
```

---

## ⚙️ Configuration

### `Config/server.conf` File

This file contains all server configuration.

#### 📌 Patchline

```bash
# Server version to download
# Options: release, pre-release
PATCHLINE=release
```

#### 📌 Java Options (JVM)

```bash
# Memory allocated to server
JAVA_MEMORY="-Xmx4G -Xms2G"

# Additional Java options
JAVA_EXTRA_OPTS="--enable-native-access=ALL-UNNAMED"
```

**Memory recommendations:**
- Small server (1-5 players): `-Xmx2G -Xms1G`
- Medium (5-10 players): `-Xmx4G -Xms2G`
- Large (10-20 players): `-Xmx8G -Xms4G`
- Very large (20+): `-Xmx16G -Xms8G`

#### 📌 Hytale Server Options

```bash
# Disable Sentry (telemetry)
DISABLE_SENTRY="--disable-sentry"

# Accept early plugins (WARNING: may cause stability issues)
ACCEPT_EARLY_PLUGINS="--disable-sentry"
# ACCEPT_EARLY_PLUGINS="--accept-early-plugins"  # Uncomment to enable

# Authentication mode
AUTH_MODE=""
# AUTH_MODE="--auth-mode offline"  # Offline mode

# Server port (default: 5520)
BIND_ADDRESS=""
# BIND_ADDRESS="--bind 0.0.0.0:25565"  # Custom port

# Automatic backups
AUTO_BACKUP=""
# AUTO_BACKUP="--backup --backup-frequency 30 --backup-max-count 5"

# Additional options
EXTRA_SERVER_OPTS=""
```

#### 📌 Paths and Files

```bash
# Backup directory
BACKUP_DIR="Backups"

# Number of backups to keep
BACKUP_RETENTION=10

# Logs directory
LOGS_DIR="Logs"

# Main log file
LOG_FILE=""  # Default: Logs/server.log
```

---

## 🎮 Available Commands

### Installation

```bash
./manage-hytale-server.sh install
```
Complete installation from scratch.

### Start

```bash
# Normal mode
./manage-hytale-server.sh start normal

# AOT mode (faster startup)
./manage-hytale-server.sh start aot

# With custom port
./manage-hytale-server.sh start normal --port 25565
```

**AOT Mode:** Uses Ahead-Of-Time cache (JEP-514) for faster startup without JIT warmup.

### Stop

```bash
./manage-hytale-server.sh stop
```
Stops the server gracefully (max 30 seconds wait, then forced stop if needed).

### Restart

```bash
# Normal mode
./manage-hytale-server.sh restart normal

# AOT mode
./manage-hytale-server.sh restart aot

# With custom port
./manage-hytale-server.sh restart aot --port 5521
```

### Update

```bash
./manage-hytale-server.sh update
```

This command will:
1. Create initial backup (if doesn't exist)
2. Create server data backup
3. Download new version
4. Restore configuration files

**Important:** Server must be stopped before updating.

### Backups

```bash
# Backup server data
./manage-hytale-server.sh backup

# Initial backup (credentials and configs)
./manage-hytale-server.sh backup-initial
```

**Server backup** saves:
- `Server/mods/`
- `Server/universe/`
- `Server/bans.json`
- `Server/permissions.json`
- `Server/whitelist.json`

**Initial backup** saves (once):
- `Config/.hytale-downloader-credentials.json`
- `Server/auth.enc`
- `Server/config.json`
- `Config/server.conf`

### Status

```bash
./manage-hytale-server.sh status
```

Displays:
- Server status (RUNNING / STOPPED)
- PID and process information
- List of installed mods with name, version, and description

### Logs

```bash
./manage-hytale-server.sh logs
```
Display logs in real-time (Ctrl+C to quit).

### Help

```bash
./manage-hytale-server.sh help
```

---

## 🧩 Mod Management

### Installing Mods

1. Place `.jar` or `.zip` files in `Server/mods/`
2. Restart the server

### Automatic Manifest Extraction

On startup, the script:
1. Extracts `manifest.json` from each `.jar` file
2. Saves to `Mods-Manifest/`
3. Creates a summary file `mods_summary.txt`

---

## 💾 Backups

### Backup Types

#### 1. Initial Backup (`initial_backup.tar.gz`)
- **Created:** Automatically during installation or update
- **Content:** Credentials and configuration files
- **Frequency:** Once (doesn't recreate if exists)
- **Location:** `Backups/initial_backup.tar.gz`

#### 2. Server Backup (`server_backup_YYYYMMDD_HHMMSS.tar.gz`)
- **Created:** Manually with `./manage-hytale-server.sh backup`
- **Content:** Mods, world, bans, permissions, whitelist
- **Frequency:** On demand
- **Retention:** Defined by `BACKUP_RETENTION` (default: 10)
- **Location:** `Backups/server_backup_*.tar.gz`

### Restoring a Backup

```bash
# Stop server
./manage-hytale-server.sh stop

# List backups
ls -lh Backups/

# Extract backup
cd /root/hytale
tar -xzf Backups/server_backup_20260118_143000.tar.gz

# Restart
./manage-hytale-server.sh start normal
```

### Automating Backups

Create a cron job:

```bash
# Edit crontab
crontab -e

# Daily backup at 3 AM
0 3 * * * /root/hytale/manage-hytale-server.sh backup

# Backup every 6 hours
0 */6 * * * /root/hytale/manage-hytale-server.sh backup
```

---

## 📄 License

This script is provided "as is" without warranty. Use at your own risk.

---

## 🔗 Useful Links

- [Official Hytale Documentation](https://support.hytale.com/)
- [Hytale Downloader](https://downloader.hytale.com/)

---

**Script Version:** 2.0  
**Last Updated:** 2026-01-20
