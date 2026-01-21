#!/bin/bash

################################################################################
# Clear Function for Hytale Server Management
################################################################################

# Clear universe (world data)
clear_universe() {
    log_step "Clearing universe (world data)..."
    
    # Check if server is running
    if is_server_running; then
        log_error "Server is running"
        log_info "Stop it first: $0 stop"
        exit 1
    fi
    
    local universe_dir="$SERVER_DIR/universe"
    
    # Check if universe directory exists
    if [ ! -d "$universe_dir" ]; then
        log_warning "Universe directory not found: $universe_dir"
        log_info "Nothing to clear"
        return 0
    fi
    
    # Get directory size
    local size=$(du -sh "$universe_dir" 2>/dev/null | cut -f1)
    
    # Ask for confirmation
    echo ""
    log_warning "This will permanently delete the world data!"
    log_info "Directory: $universe_dir"
    log_info "Size: $size"
    echo ""
    read -p "Are you sure you want to continue? (yes/no): " confirmation
    
    if [ "$confirmation" != "yes" ]; then
        log_info "Operation cancelled"
        return 0
    fi
    
    # Create backup before deletion
    log_info "Creating backup before deletion..."
    backup_server_data
    echo ""
    
    # Delete universe directory
    log_info "Deleting universe directory..."
    rm -rf "$universe_dir"
    
    if [ ! -d "$universe_dir" ]; then
        log_success "Universe directory deleted successfully"
        log_info "A new world will be generated on next server start"
    else
        log_error "Failed to delete universe directory"
        exit 1
    fi
}
