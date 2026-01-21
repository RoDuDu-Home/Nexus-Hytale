#!/bin/bash

################################################################################
# Server Manager - Start/Stop/Restart/Screen Management
################################################################################

readonly SCREEN_SESSION="hytale-server"

# Start the server
start_server() {
    local mode="${1:-normal}"
    local port="${2:-}"
    local interactive="${3:-false}"
    
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
    
    # Check if screen is installed
    if ! command -v screen &>/dev/null; then
        log_error "screen is not installed"
        log_info "Install with: apt-get install screen"
        exit 1
    fi
    
    # Configuration from server.conf
    local java_opts="$JAVA_OPTS"
    local assets_path="${ASSETS_ZIP}"
    [ ! -f "$assets_path" ] && assets_path="$SCRIPT_DIR/HytaleAssets"
    
    # Build server options with assets
    local server_opts="--assets $assets_path $SERVER_OPTS"
    
    # Add port if specified
    if [ -n "$port" ]; then
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
    [ "$interactive" = "true" ] && log_info "Interactive: Yes (foreground)"
    echo ""
    
    # Extract mod manifests
    extract_mod_manifests
    echo ""
    
    # Ensure logs directory exists
    mkdir -p "$LOGS_DIR"
    
    cd "$SERVER_DIR"
    
    # Build java command
    local java_cmd
    if [ "$mode" = "aot" ]; then
        log_info "Starting with AOT cache (JEP-514)..."
        log_info "Benefits: Faster startup, no JIT warmup"
        java_cmd="java -XX:AOTCache=HytaleServer.aot $java_opts -jar HytaleServer.jar $server_opts"
    else
        log_info "Starting in normal mode..."
        java_cmd="java $java_opts -jar HytaleServer.jar $server_opts"
    fi
    
    # Start in interactive or background mode
    if [ "$interactive" = "true" ]; then
        log_info "Starting in interactive mode (Ctrl+A then D to detach)..."
        echo ""
        sleep 1
        screen -S "$SCREEN_SESSION" $java_cmd
    else
        log_info "Starting in screen session: $SCREEN_SESSION"
        screen -dmS "$SCREEN_SESSION" bash -c "cd '$SERVER_DIR' && $java_cmd"
        
        sleep 2
        local pid=$(screen -ls | grep "$SCREEN_SESSION" | awk '{print $1}' | cut -d'.' -f1)
        
        if [ -n "$pid" ] && ps -p "$pid" &>/dev/null; then
            echo "$pid" > "$PID_FILE"
            log_success "Server started in screen session (PID: $pid)"
            log_info "Attach to console: $0 attach"
            log_info "View logs: $0 logs"
            log_info "Stop: $0 stop"
        else
            log_error "Server failed to start"
            log_info "Check: screen -ls"
            exit 1
        fi
    fi
}

# Stop the server
stop_server() {
    log_step "Stopping server..."
    
    if ! is_server_running; then
        log_warning "Server is not running"
        if command -v screen &>/dev/null && screen -ls | grep -q "$SCREEN_SESSION"; then
            log_info "Cleaning up orphaned screen session..."
            screen -S "$SCREEN_SESSION" -X quit 2>/dev/null || true
        fi
        return 0
    fi
    
    local pid=$(cat "$PID_FILE")
    log_info "Sending stop signal to process $pid..."
    
    if command -v screen &>/dev/null && screen -ls | grep -q "$SCREEN_SESSION"; then
        log_info "Sending stop command to server console..."
        screen -S "$SCREEN_SESSION" -X stuff "stop^M"
        
        local count=0
        while ps -p "$pid" &>/dev/null && [ $count -lt 30 ]; do
            sleep 1
            count=$((count + 1))
            echo -n "."
        done
        echo ""
        
        if ps -p "$pid" &>/dev/null; then
            log_warning "Graceful shutdown timeout, force stopping..."
            kill "$pid" 2>/dev/null || true
            sleep 2
        fi
        
        if ps -p "$pid" &>/dev/null; then
            log_warning "Force killing process..."
            kill -9 "$pid" 2>/dev/null || true
            sleep 1
        fi
        
        screen -S "$SCREEN_SESSION" -X quit 2>/dev/null || true
    else
        kill "$pid" 2>/dev/null || true
        
        local count=0
        while ps -p "$pid" &>/dev/null && [ $count -lt 30 ]; do
            sleep 1
            count=$((count + 1))
            echo -n "."
        done
        echo ""
        
        if ps -p "$pid" &>/dev/null; then
            log_warning "Force stopping..."
            kill -9 "$pid" 2>/dev/null || true
            sleep 1
        fi
    fi
    
    rm -f "$PID_FILE"
    log_success "Server stopped"
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

# Attach to running server console
attach_server() {
    log_step "Attaching to server console..."
    
    if ! is_server_running; then
        log_error "Server is not running"
        log_info "Start it: $0 start"
        exit 1
    fi
    
    if ! command -v screen &>/dev/null; then
        log_error "screen is not installed"
        log_info "Install with: apt-get install screen"
        exit 1
    fi
    
    if ! screen -ls | grep -q "$SCREEN_SESSION"; then
        log_error "Screen session '$SCREEN_SESSION' not found"
        log_info "The server may have been started without screen"
        log_info "Available sessions:"
        screen -ls
        exit 1
    fi
    
    log_info "Attaching to screen session: $SCREEN_SESSION"
    log_info "To detach: Press Ctrl+A then D (server will continue running)"
    echo ""
    sleep 1
    
    screen -r "$SCREEN_SESSION"
}
