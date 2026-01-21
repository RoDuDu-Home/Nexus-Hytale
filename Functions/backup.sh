#!/bin/bash

################################################################################
# Backup Functions for Hytale Server Management
################################################################################

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
