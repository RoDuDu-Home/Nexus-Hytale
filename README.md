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
ACCEPT_EARLY_PLUGINS=""
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

## 🎨 Usage Examples

### Scenario 1: Installation and First Start

```bash
# Installation
./manage-hytale-server.sh install

# Start in normal mode
./manage-hytale-server.sh start normal

# Check status
./manage-hytale-server.sh status

# View logs
./manage-hytale-server.sh logs
```

### Scenario 2: Change Allocated Memory

```bash
# Edit configuration
nano Config/server.conf

# Modify JAVA_MEMORY
JAVA_MEMORY="-Xmx8G -Xms4G"

# Restart server
./manage-hytale-server.sh restart normal
```

### Scenario 3: Enable Early Plugins

```bash
# Edit configuration
nano Config/server.conf

# Uncomment the line
ACCEPT_EARLY_PLUGINS="--accept-early-plugins"

# Restart
./manage-hytale-server.sh restart normal
```

### Scenario 4: Server Update

```bash
# Stop server
./manage-hytale-server.sh stop

# Update
./manage-hytale-server.sh update

# Restart in AOT mode
./manage-hytale-server.sh start aot
```

### Scenario 5: Backup Before Maintenance

```bash
# Create backup
./manage-hytale-server.sh backup

# Stop server
./manage-hytale-server.sh stop

# Perform maintenance...

# Restart
./manage-hytale-server.sh start normal
```

### Scenario 6: Using Environment Variables

```bash
# Start with more memory (temporary)
JAVA_OPTS="-Xmx16G -Xms8G" ./manage-hytale-server.sh start normal

# Download pre-release version
PATCHLINE=pre-release ./manage-hytale-server.sh update
```

---

## 🧩 Mod Management

### Installing Mods

1. Place `.jar` files in `Server/mods/`
2. Restart the server

```bash
# Copy a mod
cp my-mod.jar Server/mods/

# Restart
./manage-hytale-server.sh restart normal
```

### Automatic Manifest Extraction

On startup, the script:
1. Extracts `manifest.json` from each `.jar` file
2. Saves to `Mods-Manifest/`
3. Creates a summary file `mods_summary.txt`

### Displaying Mods

```bash
./manage-hytale-server.sh status
```

Example output:

```
[INFO] Installed mods:

  NAME                                VERSION              DESCRIPTION
  ─────────────────────────────────── ──────────────────── ─────────────────────────────────────────────
  LevelingCore                        0.2.0                A modern, flexible leveling system for Hyt...
  Hybrid                              1.5                  Hybrid is a mod library that contains com...
  MultipleHUD                         1.0.1                A simple mod that allows you to have mult...
  Party Plugin                        1.3.8                Create parties with friends, see their hp...
  AdvancedItemInfo                    1.0.4                Adds a command to open a GUI with all the...
  EyeSpy                              2026.1.14-55560      -
  AutoAnnounce                        1.1.1                Automatically broadcasts announcements to...
  Overstacked                         2026.1.12-30731      Configure the max stack size of items!

[INFO] Total: 8 mod(s) - Manifests: /root/hytale/Mods-Manifest/
```

### Removing Mods

```bash
# Stop server
./manage-hytale-server.sh stop

# Remove mod
rm Server/mods/my-mod.jar

# Restart
./manage-hytale-server.sh start normal
```

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

## 🔍 Troubleshooting

### Server Won't Start

**Check logs:**
```bash
cat Logs/server.log
```

**Common causes:**
- Insufficient memory → Increase `JAVA_MEMORY`
- Port already in use → Change port
- Corrupted files → Reinstall with `./manage-hytale-server.sh install`

### Authentication Error

```bash
# Remove credentials
rm Config/.hytale-downloader-credentials.json

# Reinstall
./manage-hytale-server.sh install
```

### Server Stops Unexpectedly

**Check memory:**
```bash
free -h
```

**Check logs:**
```bash
tail -100 Logs/server.log
```

**Increase memory:**
```bash
nano Config/server.conf
# JAVA_MEMORY="-Xmx8G -Xms4G"
```

### Mods Not Displaying

**Check jq is installed:**
```bash
apt-get install jq
```

**Check manifests:**
```bash
ls -lh Mods-Manifest/
cat Mods-Manifest/mods_summary.txt
```

**Restart to regenerate:**
```bash
./manage-hytale-server.sh restart normal
```

### Permission Issues

```bash
# Set correct permissions
chmod +x manage-hytale-server.sh
chmod +x Download/hytale-downloader

# Check ownership
chown -R root:root /root/hytale
```

### Server Won't Stop

```bash
# Check PID
cat .hytale-server.pid

# Force stop manually
kill -9 $(cat .hytale-server.pid)
rm .hytale-server.pid
```

---

## 📝 Important Notes

### Security

- ⚠️ Never share `Config/.hytale-downloader-credentials.json`
- ⚠️ Regularly backup `Backups/initial_backup.tar.gz`
- ⚠️ Use a firewall to limit access to server port

### Performance

- 💡 AOT mode is recommended for frequent restarts
- 💡 Allocate at least 4GB RAM for stable server
- 💡 Use SSD for better performance

### Maintenance

- 🔄 Check for updates regularly
- 🔄 Clean old logs: `rm Logs/server.log.old`
- 🔄 Check disk space: `df -h`

---

## 🆘 Support

### Useful Logs

```bash
# Server logs
cat Logs/server.log

# Last lines
tail -50 Logs/server.log

# Real-time logs
./manage-hytale-server.sh logs
```

### System Information

```bash
# Java version
java -version

# Available memory
free -h

# Disk space
df -h

# Server process
ps aux | grep -i hytale
```

### Complete Reset

```bash
# WARNING: Deletes everything!
./manage-hytale-server.sh stop
cd /root
rm -rf hytale
mkdir hytale
cd hytale
# Copy script and start over
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
