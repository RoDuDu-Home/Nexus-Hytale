#!/bin/bash

################################################################################
# Logs Function for Hytale Server Management
################################################################################

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
