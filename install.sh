#!/bin/bash
# ==============================================================================
# PROJECT: Tox1c SSH-Tunnel | Enterprise Edition (Fixed)
# AUTHOR:  Tox1c
# VERSION: 3.0-Dev
# ==============================================================================

set -Eeuo pipefail
trap cleanup SIGINT SIGTERM ERR EXIT

# --- CONSTANTS ---
readonly INSTALL_DIR="/opt/tox1c-sshtunnel"
readonly LOG_FILE="/var/log/tox1c-install.log"
readonly REPO_URL="https://github.com/Tox1cs/ssh-tunnel.git"
readonly BIN_LINK="/usr/local/bin/tox1c"

# --- COLORS ---
readonly C_RED='\033[0;31m'
readonly C_GREEN='\033[0;32m'
readonly C_YELLOW='\033[1;33m'
readonly C_BLUE='\033[0;34m'
readonly C_CYAN='\033[0;36m'
readonly C_NC='\033[0m'

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd -P)

# --- UTILS ---
log() {
    local type="$1"
    local msg="$2"
    local timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    echo "[$timestamp] [$type] $msg" >> "$LOG_FILE"
}

msg() {
    local text="$1"
    echo -e "${C_CYAN}[*] ${text}${C_NC}"
    log "INFO" "$text"
}

success() {
    echo -e "${C_GREEN}[✔] $1${C_NC}"
    log "SUCCESS" "$1"
}

error() {
    echo -e "${C_RED}[✘] ERROR: $1${C_NC}"
    log "ERROR" "$1"
    exit 1
}

cleanup() {
    trap - SIGINT SIGTERM ERR EXIT
    rm -rf /tmp/tox1c-build
}

# --- MAIN LOGIC ---

# 1. Root Check
[[ $EUID -ne 0 ]] && error "This script must be run as root."

clear
echo -e "${C_CYAN}"
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║             TOX1C SSH-TUNNEL | ENTERPRISE INSTALLER          ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo -e "${C_NC}"

log "START" "Installation started."

# 2. Dependencies
msg "Updating system and installing dependencies..."
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq >> "$LOG_FILE" 2>&1 || true
apt-get install -y -qq build-essential cmake git ufw fail2ban vnstat curl dnsutils >> "$LOG_FILE" 2>&1
success "Dependencies installed."

# 3. Kernel Optimization
msg "Applying Kernel Performance Tuning..."
cat > /etc/sysctl.d/99-tox1c-tuning.conf <<EOF
# TOX1C PERFORMANCE TUNING
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
net.ipv4.tcp_rmem = 4096 87380 16777216
net.ipv4.tcp_wmem = 4096 65536 16777216
net.ipv4.tcp_fastopen = 3
net.ipv4.tcp_slow_start_after_idle = 0
EOF
sysctl -p /etc/sysctl.d/99-tox1c-tuning.conf >> "$LOG_FILE" 2>&1 || true
success "Kernel tuned for high throughput."

# 4. Directory Structure
msg "Initializing file structure..."
mkdir -p "${INSTALL_DIR}/bin" "${INSTALL_DIR}/config"
chmod 700 "${INSTALL_DIR}"
success "Directory structure secured."

# 5. UDP Gateway Compilation
if [[ ! -f "${INSTALL_DIR}/bin/tox1c-udpgw" ]]; then
    msg "Compiling High-Performance UDP Gateway..."
    git clone https://github.com/ambrop72/badvpn.git /tmp/tox1c-build --quiet
    mkdir -p /tmp/tox1c-build/build
    cd /tmp/tox1c-build/build
    cmake .. -DBUILD_NOTHING_BY_DEFAULT=1 -DBUILD_UDPGW=1 -DCMAKE_C_FLAGS="-O3" >> "$LOG_FILE" 2>&1
    make install >> "$LOG_FILE" 2>&1
    cp udpgw/badvpn-udpgw "${INSTALL_DIR}/bin/tox1c-udpgw"
    chmod 755 "${INSTALL_DIR}/bin/tox1c-udpgw"
    success "Gateway compiled and installed."
else
    success "Gateway already exists. Skipping compilation."
fi

# 6. Service Configuration
msg "Configuring Systemd Services..."

# Asset: Banner
if [[ ! -f "${INSTALL_DIR}/config/banner.txt" ]]; then
    cp "${script_dir}/assets/banner.txt" "${INSTALL_DIR}/config/banner.txt" 2>/dev/null || echo "Authorized Access Only" > "${INSTALL_DIR}/config/banner.txt"
fi

# Asset: Service File
cp "${script_dir}/assets/service.conf" /etc/systemd/system/tox1c-tunnel.service
sed -i "s|EXEC_PATH|${INSTALL_DIR}/bin/tox1c-udpgw|g" /etc/systemd/system/tox1c-tunnel.service

systemctl daemon-reload
systemctl enable --now tox1c-tunnel.service >> "$LOG_FILE" 2>&1
success "Background services active."

# 7. SSH Hardening & Config (FIXED)
msg "Hardening SSH Configuration..."
groupadd -f tox1c-users
mkdir -p /etc/ssh/sshd_config.d

# FIX: Removed UseDNS and TCPKeepAlive from Match block (Illegal in SSHD)
cat > /etc/ssh/sshd_config.d/99-tox1c.conf <<EOF
Match Group tox1c-users
    Banner ${INSTALL_DIR}/config/banner.txt
    ForceCommand /usr/sbin/nologin
    X11Forwarding no
    AllowAgentForwarding no
    AllowTcpForwarding yes
    PermitTunnel yes
    PasswordAuthentication yes
EOF

# Ensure Include exists
if ! grep -q "^Include /etc/ssh/sshd_config.d/\*.conf" /etc/ssh/sshd_config; then
    sed -i '1i Include /etc/ssh/sshd_config.d/*.conf' /etc/ssh/sshd_config
fi

# Validation Check before restart
if sshd -t; then
    systemctl restart ssh
    success "SSH configured successfully."
else
    error "SSH Configuration test failed! Reverting..."
    rm /etc/ssh/sshd_config.d/99-tox1c.conf
    systemctl restart ssh
fi

# 8. Dashboard Installation
msg "Installing Management Dashboard..."
cp "${script_dir}/src/manager.sh" "${INSTALL_DIR}/bin/manager"
chmod 700 "${INSTALL_DIR}/bin/manager"
ln -sf "${INSTALL_DIR}/bin/manager" "${BIN_LINK}"
success "Dashboard installed."

# 9. Firewall
msg "Configuring Firewall..."
current_port=$(grep "^Port " /etc/ssh/sshd_config | head -n1 | awk '{print $2}') || current_port=22
ufw allow "${current_port}/tcp" >> "$LOG_FILE" 2>&1
ufw reload >> "$LOG_FILE" 2>&1
success "Firewall secured on Port ${current_port}."

echo ""
echo -e "${C_GREEN}══════════════════════════════════════════════════════════════${C_NC}"
echo -e "   ${C_CYAN}INSTALLATION COMPLETE${C_NC}"
echo -e "   Run command: ${C_YELLOW}tox1c${C_NC}"
echo -e "${C_GREEN}══════════════════════════════════════════════════════════════${C_NC}"
