#!/bin/bash

################################################################################
# Configuration Management for Hytale Server
################################################################################

# Load and initialize configuration
load_configuration() {
    # Load configuration if it exists
    if [ -f "$CONFIG_FILE" ]; then
        echo -e "${BLUE:-}[INFO]${NC:-} Loading configuration from: $CONFIG_FILE"
        source "$CONFIG_FILE"
    else
        echo -e "${YELLOW:-}[WARNING]${NC:-} Configuration file not found: $CONFIG_FILE"
        echo -e "${YELLOW:-}[WARNING]${NC:-} Using default values"
    fi
}

# Initialize configuration variables with defaults
init_config_vars() {
    # Default values if not defined in server.conf
    PATCHLINE="${PATCHLINE:-release}"
    
    # Convert relative paths to absolute paths
    BACKUP_DIR=$(to_absolute_path "${BACKUP_DIR:-}" "$SCRIPT_DIR/Backups")
    LOGS_DIR=$(to_absolute_path "${LOGS_DIR:-}" "$SCRIPT_DIR/Logs")
    LOG_FILE=$(to_absolute_path "${LOG_FILE:-}" "$LOGS_DIR/server.log")
    BACKUP_RETENTION="${BACKUP_RETENTION:-10}"
    
    # Build JAVA_OPTS if not defined
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
}

# Make configuration variables readonly
finalize_config() {
    readonly PATCHLINE
    readonly BACKUP_DIR
    readonly BACKUP_RETENTION
    readonly LOGS_DIR
    readonly LOG_FILE
    readonly JAVA_OPTS
    readonly SERVER_OPTS
}

# Perform configuration migrations
migrate_config_files() {
    # Migration: move configuration files to Config/ if necessary
    if [ -f "$SCRIPT_DIR/.hytale-downloader-credentials.json" ]; then
        mv "$SCRIPT_DIR/.hytale-downloader-credentials.json" "$CREDENTIALS_FILE"
        echo -e "${BLUE:-}[INFO]${NC:-} Migration: credentials moved to Config/"
    fi
    
    if [ -f "$SCRIPT_DIR/server.conf" ]; then
        mv "$SCRIPT_DIR/server.conf" "$CONFIG_FILE"
        echo -e "${BLUE:-}[INFO]${NC:-} Migration: server.conf moved to Config/"
    fi
}
