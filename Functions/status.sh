#!/bin/bash

################################################################################
# Status - Server Status and Mods Management
################################################################################

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
