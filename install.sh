#!/bin/bash
# ==============================================================================
# PROJECT: Tox1c SSH-Tunnel | Enterprise Edition (Refactored)
# AUTHOR:  Tox1c
# TARGET:  Dev Branch
# ==============================================================================

set -Eeuo pipefail
trap cleanup SIGINT SIGTERM ERR EXIT

# --- CONSTANTS ---
readonly INSTALL_DIR="/opt/tox1c-sshtunnel"
readonly LOG_FILE="/var/log/tox1c-install.log"
readonly BIN_LINK="/usr/local/bin/tox1c"

# --- COLORS ---
readonly C_RED='\033[0;31m'
readonly C_GREEN='\033[0;32m'
readonly C_CYAN='\033[0;36m'
readonly C_YELLOW='\033[1;33m'
readonly C_NC='\033[0m'

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd -P)

# --- UTILS ---
log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$1] $2" >> "$LOG_FILE"; }
msg() { echo -e "${C_CYAN}[*] $1${C_NC}"; log "INFO" "$1"; }
success() { echo -e "${C_GREEN}[✔] $1${C_NC}"; log "SUCCESS" "$1"; }
error() { echo -e "${C_RED}[✘] ERROR: $1${C_NC}"; log "ERROR" "$1"; exit 1; }
cleanup() { trap - SIGINT SIGTERM ERR EXIT; rm -rf /tmp/tox1c-build; }

# --- MAIN LOGIC ---
[[ $EUID -ne 0 ]] && error "Run as root."

clear
echo -e "${C_CYAN}>>> TOX1C SSH-TUNNEL: HIGH-PERFORMANCE DEPLOYMENT${C_NC}"
log "START" "Installation started."

# 1. DEPENDENCIES
msg "Installing System Dependencies..."
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq >> "$LOG_FILE" 2>&1 || true
# Added 'bc' for math operations in dashboard
apt-get install -y -qq build-essential cmake git ufw fail2ban vnstat curl dnsutils bc >> "$LOG_FILE" 2>&1
success "Dependencies ready."

# 2. KERNEL TUNING (Optimized for 1Gbps+)
msg "Injecting Kernel Parameters..."
cat > /etc/sysctl.d/99-tox1c-tuning.conf <<EOF
# TOX1C NETWORK OPTIMIZATION
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
net.ipv4.tcp_rmem = 4096 87380 16777216
net.ipv4.tcp_wmem = 4096 65536 16777216
net.ipv4.tcp_fastopen = 3
net.ipv4.tcp_mtu_probing = 1
EOF
sysctl -p /etc/sysctl.d/99-tox1c-tuning.conf >> "$LOG_FILE" 2>&1 || true
success "Kernel tuned (BBR + Huge Buffers)."

# 3. DIRECTORY STRUCTURE (Security Audit)
msg "Securing Directory Structure..."
mkdir -p "${INSTALL_DIR}/bin" "${INSTALL_DIR}/config"
# PERMISSION FIX: 755 allows 'nobody' user to read/exec, keeping 700 breaks the service
chmod 755 "${INSTALL_DIR}"
success "Permissions set to 755 (Service-Ready)."

# 4. COMPILATION (Gateway)
# Recompile if missing or broken
if [[ ! -x "${INSTALL_DIR}/bin/tox1c-udpgw" ]]; then
    msg "Compiling High-Performance UDP Gateway..."
    rm -f "${INSTALL_DIR}/bin/tox1c-udpgw"
    git clone https://github.com/ambrop72/badvpn.git /tmp/tox1c-build --quiet
    mkdir -p /tmp/tox1c-build/build
    cd /tmp/tox1c-build/build
    # -O3 flag forces compiler to optimize for maximum speed
    cmake .. -DBUILD_NOTHING_BY_DEFAULT=1 -DBUILD_UDPGW=1 -DCMAKE_C_FLAGS="-O3" >> "$LOG_FILE" 2>&1
    make install >> "$LOG_FILE" 2>&1
    cp udpgw/badvpn-udpgw "${INSTALL_DIR}/bin/tox1c-udpgw"
    chmod 755 "${INSTALL_DIR}/bin/tox1c-udpgw"
    success "Gateway compiled with -O3 optimization."
else
    success "Gateway binary verified."
fi

# 5. SERVICE CONFIGURATION
msg "Configuring Systemd Service..."
if [[ ! -f "${INSTALL_DIR}/config/banner.txt" ]]; then
    cp "${script_dir}/assets/banner.txt" "${INSTALL_DIR}/config/banner.txt" 2>/dev/null || echo "Authorized Access
