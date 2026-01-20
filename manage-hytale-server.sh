#!/bin/bash

################################################################################
# Hytale Server Management Script
# Author: Optimized script for complete server management
# Version: 2.0
################################################################################

set -euo pipefail  # Stop on error, undefined variables, errors in pipes

# Configuration
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

# Create necessary directories
mkdir -p "$CONFIG_DIR" "$DOWNLOAD_DIR" "$MODS_MANIFEST_DIR"

# Colors (defined early for migrations)
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m'

# Logging functions (defined early)
log_info() { echo -e "${BLUE}[INFO]${NC} $*"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $*"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*"; }
log_step() { echo -e "${CYAN}[STEP]${NC} $*"; }

# Migration: move configuration files to Config/ if necessary
[ -f "$SCRIPT_DIR/.hytale-downloader-credentials.json" ] && {
    mv "$SCRIPT_DIR/.hytale-downloader-credentials.json" "$CREDENTIALS_FILE"
    log_info "Migration: credentials moved to Config/"
}
[ -f "$SCRIPT_DIR/server.conf" ] && {
    mv "$SCRIPT_DIR/server.conf" "$CONFIG_FILE"
    log_info "Migration: server.conf moved to Config/"
}

# Load configuration if it exists
if [ -f "$CONFIG_FILE" ]; then
    log_info "Loading configuration from: $CONFIG_FILE"
    source "$CONFIG_FILE"
else
    log_warning "Configuration file not found: $CONFIG_FILE"
    log_warning "Using default values"
fi

# Default values if not defined in server.conf
PATCHLINE="${PATCHLINE:-release}"

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

# Convert relative paths to absolute paths
BACKUP_DIR=$(to_absolute_path "${BACKUP_DIR:-}" "$SCRIPT_DIR/Backups")
LOGS_DIR=$(to_absolute_path "${LOGS_DIR:-}" "$SCRIPT_DIR/Logs")
LOG_FILE=$(to_absolute_path "${LOG_FILE:-}" "$LOGS_DIR/server.log")
BACKUP_RETENTION="${BACKUP_RETENTION:-10}"

# Build JAVA_OPTS if not defined (from JAVA_MEMORY and JAVA_EXTRA_OPTS)
if [ -z "${JAVA_OPTS:-}" ]; then
    JAVA_MEMORY="${JAVA_MEMORY:--Xmx4G -Xms2G}"
    JAVA_EXTRA_OPTS="${JAVA_EXTRA_OPTS:---enable-native-access=ALL-UNNAMED}"
    JAVA_OPTS="$JAVA_MEMORY $JAVA_EXTRA_OPTS"
fi

# Build SERVER_OPTS if not defined
if [ -z "${SERVER_OPTS:-}" ]; then
    DISABLE_SENTRY="${DISABLE_SENTRY:---disable-sentry}"
    ACCEPT_EARLY_PLUGINS="${ACCEPT_EARLY_PLUGINS:---accept-early-plugin}"
    AUTH_MODE="${AUTH_MODE:-}"
    BIND_ADDRESS="${BIND_ADDRESS:-}"
    AUTO_BACKUP="${AUTO_BACKUP:-}"
    EXTRA_SERVER_OPTS="${EXTRA_SERVER_OPTS:-}"
    SERVER_OPTS="$DISABLE_SENTRY $ACCEPT_EARLY_PLUGINS $AUTH_MODE $BIND_ADDRESS $AUTO_BACKUP $EXTRA_SERVER_OPTS"
fi

# Make variables readonly after configuration
readonly PATCHLINE
readonly BACKUP_DIR
readonly BACKUP_RETENTION
readonly LOGS_DIR
readonly LOG_FILE
readonly JAVA_OPTS
readonly SERVER_OPTS

# Create necessary directories
mkdir -p "$LOGS_DIR" "$BACKUP_DIR"

# Function to display help
show_help() {
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}  Hytale Server Management Script v2.0${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "${YELLOW}Usage:${NC} $0 [COMMAND] [OPTIONS]"
    echo ""
    echo -e "${YELLOW}Commands:${NC}"
    echo -e "  ${GREEN}install${NC}              Complete installation from scratch"
    echo -e "  ${GREEN}start [normal|aot] [--port PORT]${NC}"
    echo -e "                       Start server (normal or AOT mode)"
    echo -e "  ${GREEN}stop${NC}                 Stop server"
    echo -e "  ${GREEN}restart [normal|aot] [--port PORT]${NC}"
    echo -e "                       Restart server"
    echo -e "  ${GREEN}update${NC}               Update server"
    echo -e "  ${GREEN}backup${NC}               Backup server data"
    echo -e "  ${GREEN}backup-initial${NC}       Initial credentials backup"
    echo -e "  ${GREEN}status${NC}               Show server status"
    echo -e "  ${GREEN}logs${NC}                 Show real-time logs"
    echo -e "  ${GREEN}help${NC}                 Show this help"
    echo ""
    echo -e "${YELLOW}Options:${NC}"
    echo -e "  --port PORT         Custom port (default: 5520)"
    echo ""
    echo -e "${YELLOW}Examples:${NC}"
    echo -e "  $0 install"
    echo -e "  $0 start aot"
    echo -e "  $0 start normal --port 25565"
    echo -e "  JAVA_OPTS=\"-Xmx8G -Xms4G\" $0 start"
    echo ""
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
}

# Check dependencies
check_dependencies() {
    log_step "Checking dependencies..."
    local missing_deps=()
    
    for cmd in unzip java wget; do
        command -v "$cmd" &>/dev/null || missing_deps+=("$cmd")
    done
    
    if [ ${#missing_deps[@]} -ne 0 ]; then
        log_error "Missing dependencies: ${missing_deps[*]}"
        log_info "Install with: apt-get install ${missing_deps[*]}"
        exit 1
    fi
    
    log_success "All dependencies are installed"
}

# Download a file
download_file() {
    local url=$1
    local output=$2
    
    if command -v wget &>/dev/null; then
        wget -q --show-progress -O "$output" "$url"
    else
        curl -L -o "$output" "$url" --progress-bar
    fi
}

# Install hytale-downloader
install_downloader() {
    log_step "Installing hytale-downloader..."
    
    local temp_zip="$DOWNLOAD_DIR/hytale-downloader-temp.zip"
    local temp_dir="$DOWNLOAD_DIR/hytale-downloader-temp"
    
    download_file "$DOWNLOADER_URL" "$temp_zip"
    
    mkdir -p "$temp_dir"
    unzip -q -o "$temp_zip" -d "$temp_dir"
    
    local binary=$(find "$temp_dir" -type f -name "hytale-downloader*" ! -name "*.exe" ! -name "*.md" | head -n 1)
    
    if [ -z "$binary" ]; then
        log_error "hytale-downloader binary not found"
        rm -rf "$temp_dir" "$temp_zip"
        exit 1
    fi
    
    mv "$binary" "$DOWNLOADER_BIN"
    chmod +x "$DOWNLOADER_BIN"
    rm -rf "$temp_dir" "$temp_zip"
    
    log_success "hytale-downloader installed in: $DOWNLOAD_DIR/"
}

# Create initial backup (credentials and configs)
backup_initial() {
    local backup_file="$BACKUP_DIR/initial_backup.tar.gz"
    
    [ -f "$backup_file" ] && { log_info "Initial backup already exists"; return 0; }
    
    log_step "Creating initial backup (credentials and configs)..."
    
    local files_to_backup=()
    local files_found=()
    local -A file_map=(
        ["$CREDENTIALS_FILE"]="Config/.hytale-downloader-credentials.json|credentials"
        ["$SERVER_DIR/auth.enc"]="Server/auth.enc|auth.enc"
        ["$SERVER_DIR/config.json"]="Server/config.json|config.json"
        ["$CONFIG_FILE"]="Config/server.conf|server.conf"
    )
    
    for file in "${!file_map[@]}"; do
        if [ -f "$file" ]; then
            IFS='|' read -r path name <<< "${file_map[$file]}"
            files_to_backup+=("$path")
            files_found+=("$name")
        fi
    done
    
    if [ ${#files_to_backup[@]} -eq 0 ]; then
        log_warning "No configuration files to backup"
        return
    fi
    
    tar -czf "$backup_file" -C "$SCRIPT_DIR" "${files_to_backup[@]}" 2>/dev/null || true
    log_success "Initial backup created ($(du -h "$backup_file" 2>/dev/null | cut -f1)): ${files_found[*]}"
}

# Create server data backup
backup_server_data() {
    log_step "Creating server data backup..."
    
    mkdir -p "$BACKUP_DIR"
    
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_file="$BACKUP_DIR/server_backup_$timestamp.tar.gz"
    local files_to_backup=()
    local dirs_to_backup=()
    
    # Fichiers JSON
    [ -f "$SERVER_DIR/bans.json" ] && files_to_backup+=("Server/bans.json")
    [ -f "$SERVER_DIR/permissions.json" ] && files_to_backup+=("Server/permissions.json")
    [ -f "$SERVER_DIR/whitelist.json" ] && files_to_backup+=("Server/whitelist.json")
    
    # Répertoires
    [ -d "$SERVER_DIR/mods" ] && dirs_to_backup+=("Server/mods")
    [ -d "$SERVER_DIR/universe" ] && dirs_to_backup+=("Server/universe")
    
    if [ ${#files_to_backup[@]} -eq 0 ] && [ ${#dirs_to_backup[@]} -eq 0 ]; then
        log_warning "No server data to backup"
        log_info "Files searched: bans.json, permissions.json, whitelist.json"
        log_info "Directories searched: mods/, universe/"
        return
    fi
    
    # Combine files and directories
    local all_items=("${files_to_backup[@]}" "${dirs_to_backup[@]}")
    
    tar -czf "$backup_file" -C "$SCRIPT_DIR" "${all_items[@]}" 2>/dev/null || true
    
    local backup_size=$(du -h "$backup_file" 2>/dev/null | cut -f1)
    log_success "Backup created: $backup_file ($backup_size)"
    
    if [ ${#files_to_backup[@]} -gt 0 ]; then
        log_info "Files: ${files_to_backup[*]}"
    fi
    if [ ${#dirs_to_backup[@]} -gt 0 ]; then
        log_info "Directories: ${dirs_to_backup[*]}"
    fi
    
    # Keep the last N backups (defined in server.conf)
    local retention=$((BACKUP_RETENTION + 1))
    ls -t "$BACKUP_DIR"/server_backup_*.tar.gz 2>/dev/null | tail -n +$retention | xargs -r rm
    
    local remaining=$(ls -1 "$BACKUP_DIR"/server_backup_*.tar.gz 2>/dev/null | wc -l)
    log_info "Backups kept: $remaining/$BACKUP_RETENTION"
}

# Display authentication instructions
show_auth_instructions() {
    log_warning "First use - OAuth2 authentication required"
    echo ""
    log_info "The hytale-downloader will display a URL and code"
    log_info "1. Open the URL in your browser"
    log_info "2. Log in with your Hytale account"
    log_info "3. Enter the code"
    echo ""
}

# Download the server
download_server() {
    log_step "Downloading Hytale server (patchline: $PATCHLINE)..."
    
    [ ! -f "$DOWNLOADER_BIN" ] && install_downloader
    
    [ ! -f "$CREDENTIALS_FILE" ] && show_auth_instructions
    
    # Create initial backup if necessary
    backup_initial
    
    # Temporarily backup configuration files
    local -a backup_files=()
    for file in auth.enc config.json; do
        [ -f "$SERVER_DIR/$file" ] && {
            cp "$SERVER_DIR/$file" "$SCRIPT_DIR/${file}.backup"
            backup_files+=("$file")
        }
    done
    [ ${#backup_files[@]} -gt 0 ] && log_info "Temporary backup: ${backup_files[*]}"
    
    local download_path="$DOWNLOAD_DIR/hytale-server-latest.zip"
    
    [ ! -f "$CREDENTIALS_FILE" ] && log_info "Starting authentication..." || log_info "Downloading..."
    echo ""
    
    # Download with error handling
    set +e
    "$DOWNLOADER_BIN" -credentials-path "$CREDENTIALS_FILE" -download-path "$download_path" -patchline "$PATCHLINE" -skip-update-check
    local exit_code=$?
    set -e
    
    if [ $exit_code -ne 0 ]; then
        echo ""
        log_error "Download failed (code: $exit_code)"
        echo ""
        log_info "Solutions:"
        log_info "  1. Authentication error: rm $CREDENTIALS_FILE && $0 install"
        log_info "  2. Check your internet connection"
        log_info "  3. Check your Hytale account access"
        log_info "  4. Downloaded files in: $DOWNLOAD_DIR/"
        exit 1
    fi
    
    [ ! -f "$download_path" ] && { log_error "Downloaded file not found"; exit 1; }
    
    echo ""
    log_info "Extracting archive..."
    unzip -q -o "$download_path" -d "$SCRIPT_DIR"
    
    # Move Assets.zip
    if [ -f "$SCRIPT_DIR/Assets.zip" ]; then
        mkdir -p "$SERVER_DIR"
        mv "$SCRIPT_DIR/Assets.zip" "$ASSETS_ZIP"
        log_success "Assets.zip moved to Server/"
    fi
    
    # Restore configuration files
    mkdir -p "$SERVER_DIR"
    for file in auth.enc config.json; do
        [ -f "$SCRIPT_DIR/${file}.backup" ] && {
            mv "$SCRIPT_DIR/${file}.backup" "$SERVER_DIR/$file"
            log_success "$file restored"
        }
    done
    
    rm -f "$download_path"
    log_success "Server installed successfully"
}

# Complete installation
install_complete() {
    log_info "Complete Hytale Server Installation"
    echo ""
    check_dependencies
    echo ""
    install_downloader
    echo ""
    download_server
    echo ""
    log_success "Installation completed!"
    log_info "Start: $0 start aot"
    echo ""
}

# Check if server is running
is_server_running() {
    [ -f "$PID_FILE" ] || return 1
    
    local pid=$(cat "$PID_FILE")
    if ps -p "$pid" &>/dev/null; then
        return 0
    else
        rm -f "$PID_FILE"
        return 1
    fi
}

# Get server status
get_status() {
    log_step "Server status..."
    echo ""
    
    if is_server_running; then
        local pid=$(cat "$PID_FILE")
        log_success "Server RUNNING (PID: $pid)"
        
        echo ""
        log_info "Process info:"
        ps -p "$pid" -o pid,ppid,cmd,%mem,%cpu,etime 2>/dev/null || true
    else
        log_warning "Server STOPPED"
    fi
    
    # Display installed mods
    show_installed_mods
}

# Stop the server
stop_server() {
    log_step "Stopping server..."
    
    if ! is_server_running; then
        log_warning "Server is not running"
        return 0
    fi
    
    local pid=$(cat "$PID_FILE")
    log_info "Sending stop signal to process $pid..."
    
    kill "$pid" 2>/dev/null || true
    
    # Wait for shutdown (max 30 seconds)
    local count=0
    while ps -p "$pid" &>/dev/null && [ $count -lt 30 ]; do
        sleep 1
        count=$((count + 1))
        echo -n "."
    done
    echo ""
    
    # Force stop if necessary
    if ps -p "$pid" &>/dev/null; then
        log_warning "Force stopping..."
        kill -9 "$pid" 2>/dev/null || true
        sleep 1
    fi
    
    rm -f "$PID_FILE"
    log_success "Server stopped"
}

# Extract mod manifests
extract_mod_manifests() {
    log_step "Extracting mod manifests..."
    
    if [ ! -d "$SERVER_DIR/mods" ]; then
        log_info "No mods directory found"
        return 0
    fi
    
    # Clean manifests directory
    rm -rf "$MODS_MANIFEST_DIR" 2>/dev/null || true
    mkdir -p "$MODS_MANIFEST_DIR"
    
    local count=0
    local jar_count=0
    local summary_file="$MODS_MANIFEST_DIR/mods_summary.txt"
    
    # Create summary file
    echo "# Installed mods - Generated on $(date '+%Y-%m-%d %H:%M:%S')" > "$summary_file"
    echo "# Format: NOM|VERSION|DESCRIPTION" >> "$summary_file"
    
    # Temporarily disable stop on error for extraction
    set +e
    
    # Search for all .jar files in mods/
    for jar_file in "$SERVER_DIR/mods"/*.jar; do
        # Check if file exists (in case no .jar)
        [ -f "$jar_file" ] || continue
        
        jar_count=$((jar_count + 1))
        local jar_name=$(basename "$jar_file" .jar)
        local output_file="$MODS_MANIFEST_DIR/${jar_name}.json"
        
        # Extract manifest.json from jar
        unzip -p "$jar_file" manifest.json > "$output_file" 2>/dev/null
        
        # Check if file is not empty
        if [ -s "$output_file" ]; then
            count=$((count + 1))
            
            # Extract info and add to summary file
            if command -v jq &>/dev/null; then
                local name=$(jq -r '.Name // "N/A"' "$output_file" 2>/dev/null)
                local version=$(jq -r '.Version // "N/A"' "$output_file" 2>/dev/null)
                local description=$(jq -r '.Description // ""' "$output_file" 2>/dev/null)
                echo "$name|$version|$description" >> "$summary_file"
            fi
        else
            rm -f "$output_file" 2>/dev/null || true
        fi
    done
    
    # Also copy direct manifest.json if it exists
    if [ -f "$SERVER_DIR/mods/manifest.json" ]; then
        cp "$SERVER_DIR/mods/manifest.json" "$MODS_MANIFEST_DIR/mods_root.json" 2>/dev/null || true
        if [ -s "$MODS_MANIFEST_DIR/mods_root.json" ]; then
            count=$((count + 1))
            
            if command -v jq &>/dev/null; then
                local name=$(jq -r '.Name // "N/A"' "$MODS_MANIFEST_DIR/mods_root.json" 2>/dev/null)
                local version=$(jq -r '.Version // "N/A"' "$MODS_MANIFEST_DIR/mods_root.json" 2>/dev/null)
                local description=$(jq -r '.Description // ""' "$MODS_MANIFEST_DIR/mods_root.json" 2>/dev/null)
                echo "$name|$version|$description" >> "$summary_file"
            fi
        fi
    fi
    
    # Re-enable stop on error
    set -e
    
    if [ $count -gt 0 ]; then
        log_success "$count manifest(s) extracted from $jar_count .jar file(s)"
    else
        if [ $jar_count -gt 0 ]; then
            log_warning "No manifest found in $jar_count .jar file(s)"
        else
            log_info "No .jar files found in Server/mods/"
        fi
    fi
}

# Display installed mods
show_installed_mods() {
    echo ""
    log_info "Installed mods:"
    
    local summary_file="$MODS_MANIFEST_DIR/mods_summary.txt"
    
    if [ ! -f "$summary_file" ]; then
        echo "  No mods detected"
        echo "  Tip: Start the server to extract manifests"
        return
    fi
    
    echo ""
    printf "  %-35s %-20s %s\n" "NOM" "VERSION" "DESCRIPTION"
    printf "  %-35s %-20s %s\n" "$(printf '%.0s─' {1..35})" "$(printf '%.0s─' {1..20})" "$(printf '%.0s─' {1..45})"
    
    local mod_count=0
    
    # Read summary file line by line
    while IFS='|' read -r name version description; do
        [[ "$name" =~ ^# ]] && continue
        
        # Clean and format description
        description=$(echo "$description" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        [ -z "$description" ] && description="-"
        [ ${#description} -gt 45 ] && description="${description:0:42}..."
        
        printf "  %-35s %-20s %s\n" "$name" "$version" "$description"
        mod_count=$((mod_count + 1))
    done < "$summary_file"
    
    echo ""
    log_info "Total: $mod_count mod(s) - Manifests: $MODS_MANIFEST_DIR/"
}

# Start the server
start_server() {
    local mode="${1:-normal}"
    local port="${2:-}"
    
    log_step "Starting server in $mode mode..."
    
    # Checks
    if is_server_running; then
        log_error "Server is already running (PID: $(cat "$PID_FILE"))"
        log_info "Use: $0 stop"
        exit 1
    fi
    
    if [ ! -f "$SERVER_DIR/HytaleServer.jar" ]; then
        log_error "HytaleServer.jar not found"
        log_info "Run: $0 install"
        exit 1
    fi
    
    if [ "$mode" = "aot" ] && [ ! -f "$SERVER_DIR/HytaleServer.aot" ]; then
        log_warning "HytaleServer.aot not found, starting in normal mode"
        mode="normal"
    fi
    
    # Configuration from server.conf
    local java_opts="$JAVA_OPTS"
    local assets_path="${ASSETS_ZIP}"
    [ ! -f "$assets_path" ] && assets_path="$SCRIPT_DIR/HytaleAssets"
    
    # Build server options with assets
    local server_opts="--assets $assets_path $SERVER_OPTS"
    
    # Add port if specified
    if [ -n "$port" ]; then
        # Validate port
        if [[ "$port" =~ ^[0-9]+$ ]] && [ "$port" -ge 1024 ] && [ "$port" -le 65535 ]; then
            server_opts="$server_opts --bind 0.0.0.0:$port"
            log_info "Custom port: $port"
        else
            log_error "Invalid port: $port (must be between 1024 and 65535)"
            exit 1
        fi
    else
        log_info "Default port: 5520"
    fi
    
    log_info "Mode: $mode"
    log_info "JVM: $java_opts"
    log_info "Assets: $assets_path"
    log_info "Options: $server_opts"
    echo ""
    
    # Extract mod manifests
    extract_mod_manifests
    echo ""
    
    # Ensure logs directory exists
    mkdir -p "$LOGS_DIR"
    
    cd "$SERVER_DIR"
    
    # Start according to mode
    if [ "$mode" = "aot" ]; then
        log_info "Starting with AOT cache (JEP-514)..."
        log_info "Benefits: Faster startup, no JIT warmup"
        nohup java -XX:AOTCache=HytaleServer.aot $java_opts -jar HytaleServer.jar $server_opts >> "$LOG_FILE" 2>&1 &
    else
        log_info "Starting in normal mode..."
        nohup java $java_opts -jar HytaleServer.jar $server_opts >> "$LOG_FILE" 2>&1 &
    fi
    
    local pid=$!
    echo "$pid" > "$PID_FILE"
    
    # Check startup
    sleep 2
    
    if ps -p "$pid" &>/dev/null; then
        log_success "Server started (PID: $pid)"
        log_info "Logs: tail -f $LOG_FILE"
        log_info "Stop: $0 stop"
    else
        log_error "Server failed to start"
        log_info "Check: cat $LOG_FILE"
        rm -f "$PID_FILE"
        exit 1
    fi
}

# Restart the server
restart_server() {
    local mode="${1:-normal}"
    local port="${2:-}"
    
    log_step "Restarting server..."
    
    if is_server_running; then
        stop_server
        echo ""
        sleep 2
    fi
    
    start_server "$mode" "$port"
}

# Update the server
update_server() {
    log_step "Updating server..."
    echo ""
    
    if is_server_running; then
        log_error "Server is running"
        log_info "Stop it: $0 stop"
        exit 1
    fi
    
    backup_initial
    backup_server_data
    echo ""
    download_server
    echo ""
    
    log_success "Update completed"
    log_info "Restart: $0 start"
}

# Display logs
show_logs() {
    if [ ! -f "$LOG_FILE" ]; then
        log_warning "Log file not found: $LOG_FILE"
        [ -d "$LOGS_DIR" ] && ls -lh "$LOGS_DIR" 2>/dev/null
        return
    fi
    
    log_info "Displaying logs (Ctrl+C to quit): $LOG_FILE"
    echo ""
    tail -f "$LOG_FILE"
}

# Main function
main() {
    local command="${1:-help}"
    shift || true
    
    case "$command" in
        install)
            install_complete
            ;;
        start)
            local mode="normal"
            local port=""
            
            # Parse arguments
            while [ $# -gt 0 ]; do
                case "$1" in
                    normal|aot)
                        mode="$1"
                        shift
                        ;;
                    --port)
                        port="$2"
                        shift 2
                        ;;
                    *)
                        log_error "Invalid option: $1"
                        log_info "Available modes: normal, aot"
                        exit 1
                        ;;
                esac
            done
            
            start_server "$mode" "$port"
            ;;
        stop)
            stop_server
            ;;
        restart)
            local mode="normal"
            local port=""
            
            # Parse arguments
            while [ $# -gt 0 ]; do
                case "$1" in
                    normal|aot)
                        mode="$1"
                        shift
                        ;;
                    --port)
                        port="$2"
                        shift 2
                        ;;
                    *)
                        log_error "Invalid option: $1"
                        exit 1
                        ;;
                esac
            done
            
            restart_server "$mode" "$port"
            ;;
        update)
            update_server
            ;;
        backup)
            backup_server_data
            ;;
        backup-initial)
            backup_initial
            ;;
        status)
            get_status
            ;;
        logs)
            show_logs
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            log_error "Unknown command: $command"
            echo ""
            show_help
            exit 1
            ;;
    esac
}

# Execution
main "$@"
