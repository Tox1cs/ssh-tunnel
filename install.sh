#!/bin/bash
# ==============================================================================
# PROJECT: Tox1c SSH-Tunnel | Enterprise Edition (Patch 3)
# AUTHOR:  Tox1c
# VERSION: 3.0-Dev
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

# --- MAIN ---
[[ $EUID -ne 0 ]] && error "Run as root."

clear
echo -e "${C_CYAN}>>> TOX1C SSH-TUNNEL INSTALLER (Dev Build)${C_NC}"
log "START" "Installation started."

# 1. Dependencies
msg "Installing dependencies..."
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq >> "$LOG_FILE" 2>&1 || true
apt-get install -y -qq build-essential cmake git ufw fail2ban vnstat curl dnsutils >> "$LOG_FILE" 2>&1
success "Dependencies installed."

# 2. Kernel Tuning
msg "Tuning Kernel..."
cat > /etc/sysctl.d/99-tox1c-tuning.conf <<EOF
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
net.ipv4.tcp_rmem = 4096 87380 16777216
net.ipv4.tcp_wmem = 4096 65536 16777216
net.ipv4.tcp_fastopen = 3
EOF
sysctl -p /etc/sysctl.d/99-tox1c-tuning.conf >> "$LOG_FILE" 2>&1 || true
success "Kernel optimized."

# 3. Setup Directories
msg "Setting up directories..."
mkdir -p "${INSTALL_DIR}/bin" "${INSTALL_DIR}/config"
chmod 700 "${INSTALL_DIR}"
success "Directories ready."

# 4. Compile Gateway
if [[ ! -f "${INSTALL_DIR}/bin/tox1c-udpgw" ]]; then
    msg "Compiling UDP Gateway..."
    git clone https://github.com/ambrop72/badvpn.git /tmp/tox1c-build --quiet
    mkdir -p /tmp/tox1c-build/build
    cd /tmp/tox1c-build/build
    cmake .. -DBUILD_NOTHING_BY_DEFAULT=1 -DBUILD_UDPGW=1 -DCMAKE_C_FLAGS="-O3" >> "$LOG_FILE" 2>&1
    make install >> "$LOG_FILE" 2>&1
    cp udpgw/badvpn-udpgw "${INSTALL_DIR}/bin/tox1c-udpgw"
    chmod 755 "${INSTALL_DIR}/bin/tox1c-udpgw"
    success "Gateway compiled."
else
    success "Gateway already exists."
fi

# 5. Service Config
msg "Configuring Service..."
if [[ ! -f "${INSTALL_DIR}/config/banner.txt" ]]; then
    cp "${script_dir}/assets/banner.txt" "${INSTALL_DIR}/config/banner.txt" 2>/dev/null || echo "Authorized Only" > "${INSTALL_DIR}/config/banner.txt"
fi
cp "${script_dir}/assets/service.conf" /etc/systemd/system/tox1c-tunnel.service
sed -i "s|EXEC_PATH|${INSTALL_DIR}/bin/tox1c-udpgw|g" /etc/systemd/system/tox1c-tunnel.service
systemctl daemon-reload
systemctl enable --now tox1c-tunnel.service >> "$LOG_FILE" 2>&1
success "Service active."

# 6. SSH Config (THE FIX)
msg "Configuring SSH..."
groupadd -f tox1c-users
mkdir -p /etc/ssh/sshd_config.d

# FIX: Force create directories in BOTH locations to be safe
mkdir -p /run/sshd
chmod 0755 /run/sshd
chown root:root /run/sshd

mkdir -p /var/run/sshd
chmod 0755 /var/run/sshd
chown root:root /var/run/sshd

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

if ! grep -q "^Include /etc/ssh/sshd_config.d/\*.conf" /etc/ssh/sshd_config; then
    sed -i '1i Include /etc/ssh/sshd_config.d/*.conf' /etc/ssh/sshd_config
fi

# Validate and Restart
if sshd -t; then
    systemctl restart ssh
    success "SSH Configured."
else
    # Fallback: If validation fails, try to restart anyway as systemd might fix the directory on start
    echo -e "${C_YELLOW}[!] Validation failed, attempting systemd restart...${C_NC}"
    if systemctl restart ssh; then
        success "SSH Restarted Successfully."
    else
        rm /etc/ssh/sshd_config.d/99-tox1c.conf
        error "SSH Config Failed completely. Reverted changes."
    fi
fi

# 7. Dashboard
msg "Installing Dashboard..."
cp "${script_dir}/src/manager.sh" "${INSTALL_DIR}/bin/manager"
chmod 700 "${INSTALL_DIR}/bin/manager"
ln -sf "${INSTALL_DIR}/bin/manager" "${BIN_LINK}"
success "Dashboard installed."

# 8. Firewall
msg "Securing Firewall..."
current_port=$(grep "^Port " /etc/ssh/sshd_config | head -n1 | awk '{print $2}') || current_port=22
ufw allow "${current_port}/tcp" >> "$LOG_FILE" 2>&1
ufw reload >> "$LOG_FILE" 2>&1
success "Firewall set to Port ${current_port}."

echo -e "\n${C_GREEN}[✔] INSTALLATION COMPLETE.${C_NC} Run command: ${C_YELLOW}tox1c${C_NC}"
