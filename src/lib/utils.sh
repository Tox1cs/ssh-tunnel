#!/bin/bash

source "$(dirname "${BASH_SOURCE[0]}")/colors.sh"

readonly LOG_FILE="${LOG_FILE:-/var/log/tox1c.log}"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$1] $2" >> "$LOG_FILE"
}

msg() {
    echo -e "${C_CYAN}[*]${C_NC} $1"
    log "INFO" "$1"
}

success() {
    echo -e "${C_GREEN}[✔]${C_NC} $1"
    log "SUCCESS" "$1"
}

error() {
    echo -e "${C_RED}[✘]${C_NC} ERROR: $1" >&2
    log "ERROR" "$1"
}

warn() {
    echo -e "${C_YELLOW}[!]${C_NC} $1"
    log "WARN" "$1"
}

validate_username() {
    [[ "$1" =~ ^[a-zA-Z0-9_-]{3,32}$ ]]
}

validate_port() {
    [[ "$1" =~ ^[0-9]+$ ]] && [ "$1" -ge 1 ] && [ "$1" -le 65535 ]
}

validate_days() {
    [[ "$1" =~ ^[0-9]+$ ]] && [ "$1" -ge 1 ] && [ "$1" -le 3650 ]
}

is_root() {
    [ "$EUID" -eq 0 ]
}

require_root() {
    if ! is_root; then
        error "This command requires root privileges"
        exit 1
    fi
}

pause_menu() {
    echo ""
    read -rsn1 -p "Press any key to continue..."
    echo ""
}

check_command() {
    command -v "$1" &>/dev/null
}

retry() {
    local max_attempts=3
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        if "$@"; then
            return 0
        fi
        attempt=$((attempt + 1))
        [ $attempt -le $max_attempts ] && sleep 2
    done
    return 1
}
