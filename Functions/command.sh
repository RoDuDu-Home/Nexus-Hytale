#!/bin/bash

################################################################################
# Command Handler for Hytale Server Management
################################################################################

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
            local interactive="false"
            
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
                    --interactive|-i)
                        interactive="true"
                        shift
                        ;;
                    *)
                        log_error "Invalid option: $1"
                        log_info "Available modes: normal, aot"
                        log_info "Available options: --port PORT, --interactive"
                        exit 1
                        ;;
                esac
            done
            
            start_server "$mode" "$port" "$interactive"
            ;;
        attach)
            attach_server
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
        clear)
            clear_universe
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
