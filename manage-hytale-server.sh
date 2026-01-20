#!/bin/bash

################################################################################
# Script de gestion automatique du serveur Hytale
# Auteur: Script optimisé pour la gestion complète du serveur
# Version: 2.0
################################################################################

set -euo pipefail  # Arrêt en cas d'erreur, variables non définies, erreurs dans pipes

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

# Créer les répertoires nécessaires
mkdir -p "$CONFIG_DIR" "$DOWNLOAD_DIR" "$MODS_MANIFEST_DIR"

# Couleurs (définies tôt pour les migrations)
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m'

# Fonctions de logging (définies tôt)
log_info() { echo -e "${BLUE}[INFO]${NC} $*"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $*"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*"; }
log_step() { echo -e "${CYAN}[STEP]${NC} $*"; }

# Migration : déplacer les fichiers de configuration vers Config/ si nécessaire
[ -f "$SCRIPT_DIR/.hytale-downloader-credentials.json" ] && {
    mv "$SCRIPT_DIR/.hytale-downloader-credentials.json" "$CREDENTIALS_FILE"
    log_info "Migration: credentials déplacé vers Config/"
}
[ -f "$SCRIPT_DIR/server.conf" ] && {
    mv "$SCRIPT_DIR/server.conf" "$CONFIG_FILE"
    log_info "Migration: server.conf déplacé vers Config/"
}

# Charger la configuration si elle existe
if [ -f "$CONFIG_FILE" ]; then
    log_info "Chargement de la configuration depuis: $CONFIG_FILE"
    source "$CONFIG_FILE"
else
    log_warning "Fichier de configuration non trouvé: $CONFIG_FILE"
    log_warning "Utilisation des valeurs par défaut"
fi

# Valeurs par défaut si non définies dans server.conf
PATCHLINE="${PATCHLINE:-release}"

# Fonction pour convertir un chemin relatif en absolu
to_absolute_path() {
    local path="$1"
    local default="$2"
    if [ -n "$path" ]; then
        [[ "$path" != /* ]] && echo "$SCRIPT_DIR/$path" || echo "$path"
    else
        echo "$default"
    fi
}

# Convertir les chemins relatifs en chemins absolus
BACKUP_DIR=$(to_absolute_path "${BACKUP_DIR:-}" "$SCRIPT_DIR/Backups")
LOGS_DIR=$(to_absolute_path "${LOGS_DIR:-}" "$SCRIPT_DIR/Logs")
LOG_FILE=$(to_absolute_path "${LOG_FILE:-}" "$LOGS_DIR/server.log")
BACKUP_RETENTION="${BACKUP_RETENTION:-10}"

# Construire JAVA_OPTS si non défini (depuis JAVA_MEMORY et JAVA_EXTRA_OPTS)
if [ -z "${JAVA_OPTS:-}" ]; then
    JAVA_MEMORY="${JAVA_MEMORY:--Xmx4G -Xms2G}"
    JAVA_EXTRA_OPTS="${JAVA_EXTRA_OPTS:---enable-native-access=ALL-UNNAMED}"
    JAVA_OPTS="$JAVA_MEMORY $JAVA_EXTRA_OPTS"
fi

# Construire SERVER_OPTS si non défini
if [ -z "${SERVER_OPTS:-}" ]; then
    DISABLE_SENTRY="${DISABLE_SENTRY:---disable-sentry}"
    ACCEPT_EARLY_PLUGINS="${ACCEPT_EARLY_PLUGINS:---accept-early-plugin}"
    AUTH_MODE="${AUTH_MODE:-}"
    BIND_ADDRESS="${BIND_ADDRESS:-}"
    AUTO_BACKUP="${AUTO_BACKUP:-}"
    EXTRA_SERVER_OPTS="${EXTRA_SERVER_OPTS:-}"
    SERVER_OPTS="$DISABLE_SENTRY $ACCEPT_EARLY_PLUGINS $AUTH_MODE $BIND_ADDRESS $AUTO_BACKUP $EXTRA_SERVER_OPTS"
fi

# Rendre les variables readonly après configuration
readonly PATCHLINE
readonly BACKUP_DIR
readonly BACKUP_RETENTION
readonly LOGS_DIR
readonly LOG_FILE
readonly JAVA_OPTS
readonly SERVER_OPTS

# Créer les répertoires nécessaires
mkdir -p "$LOGS_DIR" "$BACKUP_DIR"

# Fonction pour afficher l'aide
show_help() {
    cat << EOF
${CYAN}═══════════════════════════════════════════════════════════════${NC}
${GREEN}  Script de Gestion du Serveur Hytale v2.0${NC}
${CYAN}═══════════════════════════════════════════════════════════════${NC}

${YELLOW}Usage:${NC} $0 [COMMANDE] [OPTIONS]

${YELLOW}Commandes:${NC}
  ${GREEN}install${NC}              Installation complète depuis zéro
  ${GREEN}start [normal|aot] [--port PORT]${NC}
                       Démarre le serveur
                       - normal: Mode standard
                       - aot: Avec cache AOT (démarrage plus rapide)
  ${GREEN}stop${NC}                 Arrête le serveur
  ${GREEN}restart [normal|aot] [--port PORT]${NC}
                       Redémarre le serveur
  ${GREEN}update${NC}               Met à jour le serveur
  ${GREEN}backup${NC}               Sauvegarde les données du serveur
                       (mods, universe, bans, permissions, whitelist)
  ${GREEN}backup-initial${NC}       Sauvegarde initiale des credentials
                       (créée automatiquement, une seule fois)
  ${GREEN}status${NC}               Affiche l'état du serveur
  ${GREEN}logs${NC}                 Affiche les logs en temps réel
  ${GREEN}help${NC}                 Affiche cette aide

${YELLOW}Options:${NC}
  --port PORT         Change le port du serveur (défaut: 5520)

${YELLOW}Variables d'environnement:${NC}
  PATCHLINE       Patchline (release|pre-release, défaut: release)
  JAVA_OPTS       Options JVM (défaut: -Xmx4G -Xms2G)
  SERVER_OPTS     Options du serveur Hytale

${YELLOW}Exemples:${NC}
  $0 install
  $0 start normal
  $0 start aot                    # Avec cache AOT (plus rapide)
  $0 start normal --port 25565
  $0 restart aot --port 5521
  JAVA_OPTS="-Xmx8G -Xms4G" $0 start
  PATCHLINE=pre-release $0 update

${CYAN}═══════════════════════════════════════════════════════════════${NC}
EOF
}

# Vérifier les dépendances
check_dependencies() {
    log_step "Vérification des dépendances..."
    local missing_deps=()
    
    for cmd in unzip java wget; do
        command -v "$cmd" &>/dev/null || missing_deps+=("$cmd")
    done
    
    if [ ${#missing_deps[@]} -ne 0 ]; then
        log_error "Dépendances manquantes: ${missing_deps[*]}"
        log_info "Installation: apt-get install ${missing_deps[*]}"
        exit 1
    fi
    
    log_success "Toutes les dépendances sont installées"
}

# Télécharger un fichier
download_file() {
    local url=$1
    local output=$2
    
    if command -v wget &>/dev/null; then
        wget -q --show-progress -O "$output" "$url"
    elif command -v curl &>/dev/null; then
        curl -L -o "$output" "$url" --progress-bar
    else
        log_error "wget ou curl requis"
        exit 1
    fi
}

# Installer hytale-downloader
install_downloader() {
    log_step "Installation du hytale-downloader..."
    
    local temp_zip="$DOWNLOAD_DIR/hytale-downloader-temp.zip"
    local temp_dir="$DOWNLOAD_DIR/hytale-downloader-temp"
    
    download_file "$DOWNLOADER_URL" "$temp_zip"
    
    mkdir -p "$temp_dir"
    unzip -q -o "$temp_zip" -d "$temp_dir"
    
    local binary=$(find "$temp_dir" -type f -name "hytale-downloader*" ! -name "*.exe" ! -name "*.md" | head -n 1)
    
    if [ -z "$binary" ]; then
        log_error "Binaire hytale-downloader non trouvé"
        rm -rf "$temp_dir" "$temp_zip"
        exit 1
    fi
    
    mv "$binary" "$DOWNLOADER_BIN"
    chmod +x "$DOWNLOADER_BIN"
    rm -rf "$temp_dir" "$temp_zip"
    
    log_success "hytale-downloader installé dans: $DOWNLOAD_DIR/"
}

# Créer une sauvegarde initiale (credentials et configs)
backup_initial() {
    local backup_file="$BACKUP_DIR/initial_backup.tar.gz"
    
    [ -f "$backup_file" ] && { log_info "Backup initial existe déjà"; return 0; }
    
    log_step "Création du backup initial (credentials et configs)..."
    
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
        log_warning "Aucun fichier de configuration à sauvegarder"
        return
    fi
    
    tar -czf "$backup_file" -C "$SCRIPT_DIR" "${files_to_backup[@]}" 2>/dev/null || true
    log_success "Backup initial créé ($(du -h "$backup_file" 2>/dev/null | cut -f1)): ${files_found[*]}"
}

# Créer une sauvegarde des données du serveur
backup_server_data() {
    log_step "Création d'une sauvegarde des données du serveur..."
    
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
        log_warning "Aucune donnée serveur à sauvegarder"
        log_info "Fichiers recherchés: bans.json, permissions.json, whitelist.json"
        log_info "Répertoires recherchés: mods/, universe/"
        return
    fi
    
    # Combiner fichiers et répertoires
    local all_items=("${files_to_backup[@]}" "${dirs_to_backup[@]}")
    
    tar -czf "$backup_file" -C "$SCRIPT_DIR" "${all_items[@]}" 2>/dev/null || true
    
    local backup_size=$(du -h "$backup_file" 2>/dev/null | cut -f1)
    log_success "Sauvegarde créée: $backup_file ($backup_size)"
    
    if [ ${#files_to_backup[@]} -gt 0 ]; then
        log_info "Fichiers: ${files_to_backup[*]}"
    fi
    if [ ${#dirs_to_backup[@]} -gt 0 ]; then
        log_info "Répertoires: ${dirs_to_backup[*]}"
    fi
    
    # Garder les N dernières sauvegardes (défini dans server.conf)
    local retention=$((BACKUP_RETENTION + 1))
    ls -t "$BACKUP_DIR"/server_backup_*.tar.gz 2>/dev/null | tail -n +$retention | xargs -r rm
    
    local remaining=$(ls -1 "$BACKUP_DIR"/server_backup_*.tar.gz 2>/dev/null | wc -l)
    log_info "Sauvegardes conservées: $remaining/$BACKUP_RETENTION"
}

# Afficher les instructions d'authentification
show_auth_instructions() {
    log_warning "Première utilisation - Authentification OAuth2 requise"
    echo ""
    log_info "═══════════════════════════════════════════════════════════════"
    log_info "  AUTHENTIFICATION OAUTH2"
    log_info "═══════════════════════════════════════════════════════════════"
    echo ""
    log_info "Le hytale-downloader va afficher:"
    log_info "  • Une URL à ouvrir dans votre navigateur"
    log_info "  • Un code d'autorisation"
    echo ""
    log_info "Procédure:"
    log_info "  1. Ouvrez l'URL dans votre navigateur"
    log_info "  2. Connectez-vous avec votre compte Hytale"
    log_info "  3. Entrez le code affiché"
    log_info "  4. Le téléchargement démarrera automatiquement"
    echo ""
    log_info "═══════════════════════════════════════════════════════════════"
    echo ""
}

# Télécharger le serveur
download_server() {
    log_step "Téléchargement du serveur Hytale (patchline: $PATCHLINE)..."
    
    [ ! -f "$DOWNLOADER_BIN" ] && install_downloader
    
    [ ! -f "$CREDENTIALS_FILE" ] && show_auth_instructions
    
    # Créer le backup initial si nécessaire
    backup_initial
    
    # Sauvegarder temporairement les fichiers de configuration
    local -a backup_files=()
    for file in auth.enc config.json; do
        [ -f "$SERVER_DIR/$file" ] && {
            cp "$SERVER_DIR/$file" "$SCRIPT_DIR/${file}.backup"
            backup_files+=("$file")
        }
    done
    [ ${#backup_files[@]} -gt 0 ] && log_info "Sauvegarde temporaire: ${backup_files[*]}"
    
    local download_path="$DOWNLOAD_DIR/hytale-server-latest.zip"
    
    [ ! -f "$CREDENTIALS_FILE" ] && log_info "Lancement de l'authentification..." || log_info "Téléchargement..."
    echo ""
    
    # Télécharger avec gestion d'erreur
    set +e
    "$DOWNLOADER_BIN" -credentials-path "$CREDENTIALS_FILE" -download-path "$download_path" -patchline "$PATCHLINE"
    local exit_code=$?
    set -e
    
    if [ $exit_code -ne 0 ]; then
        echo ""
        log_error "Échec du téléchargement (code: $exit_code)"
        echo ""
        log_info "Solutions:"
        log_info "  1. Erreur d'authentification: rm $CREDENTIALS_FILE && $0 install"
        log_info "  2. Vérifiez votre connexion internet"
        log_info "  3. Vérifiez l'accès de votre compte Hytale"
        log_info "  4. Fichiers téléchargés dans: $DOWNLOAD_DIR/"
        exit 1
    fi
    
    [ ! -f "$download_path" ] && { log_error "Fichier téléchargé introuvable"; exit 1; }
    
    echo ""
    log_info "Extraction de l'archive..."
    unzip -q -o "$download_path" -d "$SCRIPT_DIR"
    
    # Déplacer Assets.zip
    if [ -f "$SCRIPT_DIR/Assets.zip" ]; then
        mkdir -p "$SERVER_DIR"
        mv "$SCRIPT_DIR/Assets.zip" "$ASSETS_ZIP"
        log_success "Assets.zip déplacé dans Server/"
    fi
    
    # Restaurer les fichiers de configuration
    mkdir -p "$SERVER_DIR"
    for file in auth.enc config.json; do
        [ -f "$SCRIPT_DIR/${file}.backup" ] && {
            mv "$SCRIPT_DIR/${file}.backup" "$SERVER_DIR/$file"
            log_success "$file restauré"
        }
    done
    
    rm -f "$download_path"
    log_success "Serveur installé avec succès"
}

# Installation complète
install_complete() {
    log_info "═══════════════════════════════════════════════════════════════"
    log_info "  Installation complète du serveur Hytale"
    log_info "═══════════════════════════════════════════════════════════════"
    echo ""
    
    check_dependencies
    echo ""
    install_downloader
    echo ""
    download_server
    echo ""
    
    log_success "═══════════════════════════════════════════════════════════════"
    log_success "  Installation terminée!"
    log_success "═══════════════════════════════════════════════════════════════"
    echo ""
    log_info "Prochaines étapes:"
    log_info "  • Démarrer: $0 start normal"
    log_info "  • Ou mode AOT: $0 start aot"
    log_info "  • Voir les logs: $0 logs"
    echo ""
}

# Vérifier si le serveur est en cours d'exécution
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

# Obtenir le statut du serveur
get_status() {
    log_step "État du serveur..."
    echo ""
    
    if is_server_running; then
        local pid=$(cat "$PID_FILE")
        log_success "Serveur EN COURS D'EXÉCUTION (PID: $pid)"
        
        if command -v ps &>/dev/null; then
            echo ""
            log_info "Informations du processus:"
            ps -p "$pid" -o pid,ppid,cmd,%mem,%cpu,etime 2>/dev/null || true
        fi
    else
        log_warning "Serveur ARRÊTÉ"
    fi
    
    # Afficher les mods installés
    show_installed_mods
}

# Arrêter le serveur
stop_server() {
    log_step "Arrêt du serveur..."
    
    if ! is_server_running; then
        log_warning "Le serveur n'est pas en cours d'exécution"
        return 0
    fi
    
    local pid=$(cat "$PID_FILE")
    log_info "Envoi du signal d'arrêt au processus $pid..."
    
    kill "$pid" 2>/dev/null || true
    
    # Attendre l'arrêt (max 30 secondes)
    local count=0
    while ps -p "$pid" &>/dev/null && [ $count -lt 30 ]; do
        sleep 1
        ((count++))
        echo -n "."
    done
    echo ""
    
    # Arrêt forcé si nécessaire
    if ps -p "$pid" &>/dev/null; then
        log_warning "Arrêt forcé..."
        kill -9 "$pid" 2>/dev/null || true
        sleep 1
    fi
    
    rm -f "$PID_FILE"
    log_success "Serveur arrêté"
}

# Extraire les manifests des mods
extract_mod_manifests() {
    log_step "Extraction des manifests des mods..."
    
    if [ ! -d "$SERVER_DIR/mods" ]; then
        log_info "Aucun répertoire mods trouvé"
        return 0
    fi
    
    # Nettoyer le répertoire des manifests
    rm -rf "$MODS_MANIFEST_DIR" 2>/dev/null || true
    mkdir -p "$MODS_MANIFEST_DIR"
    
    local count=0
    local jar_count=0
    local summary_file="$MODS_MANIFEST_DIR/mods_summary.txt"
    
    # Créer le fichier récapitulatif
    echo "# Mods installés - Généré le $(date '+%Y-%m-%d %H:%M:%S')" > "$summary_file"
    echo "# Format: NOM|VERSION|DESCRIPTION" >> "$summary_file"
    
    # Désactiver temporairement l'arrêt sur erreur pour l'extraction
    set +e
    
    # Chercher tous les fichiers .jar dans mods/
    for jar_file in "$SERVER_DIR/mods"/*.jar; do
        # Vérifier que le fichier existe (au cas où aucun .jar)
        [ -f "$jar_file" ] || continue
        
        ((jar_count++))
        local jar_name=$(basename "$jar_file" .jar)
        local output_file="$MODS_MANIFEST_DIR/${jar_name}.json"
        
        # Extraire manifest.json du jar
        unzip -p "$jar_file" manifest.json > "$output_file" 2>/dev/null
        
        # Vérifier que le fichier n'est pas vide
        if [ -s "$output_file" ]; then
            ((count++))
            
            # Extraire les infos et les ajouter au fichier récapitulatif
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
    
    # Copier aussi le manifest.json direct s'il existe
    if [ -f "$SERVER_DIR/mods/manifest.json" ]; then
        cp "$SERVER_DIR/mods/manifest.json" "$MODS_MANIFEST_DIR/mods_root.json" 2>/dev/null || true
        if [ -s "$MODS_MANIFEST_DIR/mods_root.json" ]; then
            ((count++))
            
            if command -v jq &>/dev/null; then
                local name=$(jq -r '.Name // "N/A"' "$MODS_MANIFEST_DIR/mods_root.json" 2>/dev/null)
                local version=$(jq -r '.Version // "N/A"' "$MODS_MANIFEST_DIR/mods_root.json" 2>/dev/null)
                local description=$(jq -r '.Description // ""' "$MODS_MANIFEST_DIR/mods_root.json" 2>/dev/null)
                echo "$name|$version|$description" >> "$summary_file"
            fi
        fi
    fi
    
    # Réactiver l'arrêt sur erreur
    set -e
    
    if [ $count -gt 0 ]; then
        log_success "$count manifest(s) extrait(s) sur $jar_count fichier(s) .jar"
    else
        if [ $jar_count -gt 0 ]; then
            log_warning "Aucun manifest trouvé dans les $jar_count fichier(s) .jar"
        else
            log_info "Aucun fichier .jar trouvé dans Server/mods/"
        fi
    fi
}

# Afficher les mods installés
show_installed_mods() {
    echo ""
    log_info "Mods installés:"
    
    local summary_file="$MODS_MANIFEST_DIR/mods_summary.txt"
    
    if [ ! -f "$summary_file" ]; then
        echo "  Aucun mod détecté"
        echo "  Astuce: Démarrez le serveur pour extraire les manifests"
        return
    fi
    
    echo ""
    printf "  %-35s %-20s %s\n" "NOM" "VERSION" "DESCRIPTION"
    printf "  %-35s %-20s %s\n" "$(printf '%.0s─' {1..35})" "$(printf '%.0s─' {1..20})" "$(printf '%.0s─' {1..45})"
    
    local mod_count=0
    
    # Lire le fichier récapitulatif ligne par ligne
    while IFS='|' read -r name version description; do
        [[ "$name" =~ ^# ]] && continue
        
        # Nettoyer et formater la description
        description=$(echo "$description" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        [ -z "$description" ] && description="-"
        [ ${#description} -gt 45 ] && description="${description:0:42}..."
        
        printf "  %-35s %-20s %s\n" "$name" "$version" "$description"
        mod_count=$((mod_count + 1))
    done < "$summary_file"
    
    echo ""
    log_info "Total: $mod_count mod(s) - Manifests: $MODS_MANIFEST_DIR/"
}

# Démarrer le serveur
start_server() {
    local mode="${1:-normal}"
    local port="${2:-}"
    
    log_step "Démarrage du serveur en mode $mode..."
    
    # Vérifications
    if is_server_running; then
        log_error "Le serveur est déjà en cours d'exécution (PID: $(cat "$PID_FILE"))"
        log_info "Utilisez: $0 stop"
        exit 1
    fi
    
    if [ ! -f "$SERVER_DIR/HytaleServer.jar" ]; then
        log_error "HytaleServer.jar non trouvé"
        log_info "Exécutez: $0 install"
        exit 1
    fi
    
    if [ "$mode" = "aot" ] && [ ! -f "$SERVER_DIR/HytaleServer.aot" ]; then
        log_warning "HytaleServer.aot non trouvé, démarrage en mode normal"
        mode="normal"
    fi
    
    # Configuration depuis server.conf
    local java_opts="$JAVA_OPTS"
    local assets_path="${ASSETS_ZIP}"
    [ ! -f "$assets_path" ] && assets_path="$SCRIPT_DIR/HytaleAssets"
    
    # Construire les options du serveur avec les assets
    local server_opts="--assets $assets_path $SERVER_OPTS"
    
    # Ajouter le port si spécifié
    if [ -n "$port" ]; then
        # Valider le port
        if [[ "$port" =~ ^[0-9]+$ ]] && [ "$port" -ge 1024 ] && [ "$port" -le 65535 ]; then
            server_opts="$server_opts --bind 0.0.0.0:$port"
            log_info "Port personnalisé: $port"
        else
            log_error "Port invalide: $port (doit être entre 1024 et 65535)"
            exit 1
        fi
    else
        log_info "Port par défaut: 5520"
    fi
    
    log_info "Mode: $mode"
    log_info "JVM: $java_opts"
    log_info "Assets: $assets_path"
    log_info "Options: $server_opts"
    echo ""
    
    # Extraire les manifests des mods
    extract_mod_manifests
    echo ""
    
    # S'assurer que le répertoire de logs existe
    mkdir -p "$LOGS_DIR"
    
    cd "$SERVER_DIR"
    
    # Démarrer selon le mode
    if [ "$mode" = "aot" ]; then
        log_info "Démarrage avec cache AOT (JEP-514)..."
        log_info "Avantages: Démarrage plus rapide, pas de JIT warmup"
        nohup java -XX:AOTCache=HytaleServer.aot $java_opts -jar HytaleServer.jar $server_opts >> "$LOG_FILE" 2>&1 &
    else
        log_info "Démarrage en mode normal..."
        nohup java $java_opts -jar HytaleServer.jar $server_opts >> "$LOG_FILE" 2>&1 &
    fi
    
    local pid=$!
    echo "$pid" > "$PID_FILE"
    
    # Vérifier le démarrage
    sleep 2
    
    if ps -p "$pid" &>/dev/null; then
        log_success "Serveur démarré (PID: $pid)"
        log_info "Logs: tail -f $LOG_FILE"
        log_info "Arrêt: $0 stop"
    else
        log_error "Le serveur n'a pas pu démarrer"
        log_info "Consultez: cat $LOG_FILE"
        rm -f "$PID_FILE"
        exit 1
    fi
}

# Redémarrer le serveur
restart_server() {
    local mode="${1:-normal}"
    local port="${2:-}"
    
    log_step "Redémarrage du serveur..."
    
    if is_server_running; then
        stop_server
        echo ""
        sleep 2
    fi
    
    start_server "$mode" "$port"
}

# Mettre à jour le serveur
update_server() {
    log_step "Mise à jour du serveur..."
    echo ""
    
    if is_server_running; then
        log_error "Le serveur est en cours d'exécution"
        log_info "Arrêtez-le: $0 stop"
        exit 1
    fi
    
    backup_initial
    backup_server_data
    echo ""
    download_server
    echo ""
    
    log_success "Mise à jour terminée"
    log_info "Redémarrez: $0 start"
}

# Afficher les logs
show_logs() {
    if [ ! -f "$LOG_FILE" ]; then
        log_warning "Fichier de logs introuvable: $LOG_FILE"
        log_info "Répertoire des logs: $LOGS_DIR"
        
        # Lister les fichiers de logs disponibles
        if [ -d "$LOGS_DIR" ] && [ "$(ls -A "$LOGS_DIR" 2>/dev/null)" ]; then
            echo ""
            log_info "Fichiers de logs disponibles:"
            ls -lh "$LOGS_DIR"
        fi
        return
    fi
    
    log_info "Affichage des logs (Ctrl+C pour quitter)..."
    log_info "Fichier: $LOG_FILE"
    echo ""
    tail -f "$LOG_FILE"
}

# Fonction principale
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
            
            # Parser les arguments
            while [ $# -gt 0 ]; do
                case "$1" in
                    normal|aot)
                        mode="$1"
                        shift
                        ;;
                    compiled)
                        log_warning "'compiled' est obsolète, utilisez 'aot'"
                        mode="aot"
                        shift
                        ;;
                    --port)
                        port="$2"
                        shift 2
                        ;;
                    *)
                        log_error "Option invalide: $1"
                        log_info "Modes disponibles: normal, aot"
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
            
            # Parser les arguments
            while [ $# -gt 0 ]; do
                case "$1" in
                    normal|aot)
                        mode="$1"
                        shift
                        ;;
                    compiled)
                        log_warning "'compiled' est obsolète, utilisez 'aot'"
                        mode="aot"
                        shift
                        ;;
                    --port)
                        port="$2"
                        shift 2
                        ;;
                    *)
                        log_error "Option invalide: $1"
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
            log_error "Commande inconnue: $command"
            echo ""
            show_help
            exit 1
            ;;
    esac
}

# Exécution
main "$@"
