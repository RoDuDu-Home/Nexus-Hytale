#!/bin/bash

################################################################################
# Downloader - Install/Update/Download Management
################################################################################

# Logging functions
log_info() { echo -e "${BLUE}[INFO]${NC} $*"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $*"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*"; }
log_step() { echo -e "${CYAN}[STEP]${NC} $*"; }

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
