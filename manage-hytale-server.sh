#!/bin/bash

################################################################################
# Hytale Server Management Script
# Author: Optimized script for complete server management
# Version: 2.1 - Modular Architecture
################################################################################

set -e

# ============================================================================
# CONSTANTS - Core paths and configuration
# ============================================================================
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly CONFIG_DIR="$SCRIPT_DIR/Config"
readonly DOWNLOAD_DIR="$SCRIPT_DIR/Download"
readonly CONFIG_FILE="$CONFIG_DIR/server.conf"
readonly DOWNLOADER_URL="https://downloader.hytale.com/hytale-downloader.zip"
readonly DOWNLOADER_BIN="$DOWNLOAD_DIR/hytale-downloader"
readonly CREDENTIALS_FILE="$CONFIG_DIR/.hytale-downloader-credentials.json"
readonly SERVER_DIR="$SCRIPT_DIR/Server"
readonly ASSETS_ZIP="$SERVER_DIR/Assets.zip"
readonly PID_FILE="$SCRIPT_DIR/.hytale-server.pid"
readonly MODS_MANIFEST_DIR="$SCRIPT_DIR/Mods-Manifest"
readonly FUNCTIONS_DIR="$SCRIPT_DIR/Functions"

# ============================================================================
# COLORS
# ============================================================================
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m'

# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================
# Function to convert relative path to absolute
to_absolute_path() {
    local path="$1"
    local default="$2"
    if [ -n "$path" ]; then
        [[ "$path" != /* ]] && echo "$SCRIPT_DIR/$path" || echo "$path"
    else
        echo "$default"
    fi
}

# ============================================================================
# HELP FUNCTION
# ============================================================================
show_help() {
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}  Hytale Server Management Script v2.1${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "${YELLOW}Usage:${NC} $0 [COMMAND] [OPTIONS]"
    echo ""
    echo -e "${YELLOW}Commands:${NC}"
    echo -e "  ${GREEN}install${NC}              Complete installation from scratch"
    echo -e "  ${GREEN}start [normal|aot] [--port PORT] [--interactive]${NC}"
    echo -e "                       Start server (normal or AOT mode)"
    echo -e "  ${GREEN}attach${NC}               Attach to running server console"
    echo -e "  ${GREEN}stop${NC}                 Stop server"
    echo -e "  ${GREEN}restart [normal|aot] [--port PORT]${NC}"
    echo -e "                       Restart server"
    echo -e "  ${GREEN}update${NC}               Update server"
    echo -e "  ${GREEN}backup${NC}               Backup server data"
    echo -e "  ${GREEN}backup-initial${NC}       Initial credentials backup"
    echo -e "  ${GREEN}clear${NC}                Delete universe (world data)"
    echo -e "  ${GREEN}status${NC}               Show server status"
    echo -e "  ${GREEN}logs${NC}                 Show real-time logs"
    echo -e "  ${GREEN}help${NC}                 Show this help"
    echo ""
    echo -e "${YELLOW}Options:${NC}"
    echo -e "  --port PORT         Custom port (default: 5520)"
    echo -e "  --interactive       Start in foreground (interactive mode)"
    echo ""
    echo -e "${YELLOW}Examples:${NC}"
    echo -e "  $0 install"
    echo -e "  $0 start aot"
    echo -e "  $0 start normal --port 25565"
    echo -e "  $0 start aot --interactive"
    echo -e "  $0 attach                    # Ctrl+A then D to detach"
    echo -e "  $0 clear                     # Reset world"
    echo -e "  JAVA_OPTS=\"-Xmx8G -Xms4G\" $0 start"
    echo ""
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
}

# ============================================================================
# INITIALIZATION
# ============================================================================
# Create necessary directories
mkdir -p "$CONFIG_DIR" "$DOWNLOAD_DIR" "$MODS_MANIFEST_DIR" "$FUNCTIONS_DIR"

# Load all function modules
if [ -d "$FUNCTIONS_DIR" ]; then
    for func_file in "$FUNCTIONS_DIR"/*.sh; do
        if [ -f "$func_file" ]; then
            source "$func_file" || {
                echo "Error loading $func_file"
                exit 1
            }
        fi
    done
else
    echo "Error: Functions directory not found: $FUNCTIONS_DIR"
    exit 1
fi

# Perform configuration migrations
if type migrate_config_files &>/dev/null; then
    migrate_config_files
fi

# Load configuration
if type load_configuration &>/dev/null; then
    load_configuration
fi

# Initialize configuration variables
if type init_config_vars &>/dev/null; then
    init_config_vars
fi

# Finalize configuration (make readonly)
if type finalize_config &>/dev/null; then
    finalize_config
fi

# Create runtime directories
mkdir -p "${LOGS_DIR:-$SCRIPT_DIR/Logs}" "${BACKUP_DIR:-$SCRIPT_DIR/Backups}"

# ============================================================================
# EXECUTION
# ============================================================================
if type main &>/dev/null; then
    main "$@"
else
    echo "Error: main function not found"
    exit 1
fi
