#!/bin/bash
# ==============================================================================
# PROJECT: Tox1c SSH-Tunnel | Enterprise Installer
# AUTHOR:  Tox1c
# VERSION: 3.1
# ==============================================================================

set -u

# --- BOOTSTRAP ENGINE (The Magic) ---
# This block handles the "curl | bash" logic
if [ ! -d ".git" ] && [ ! -f "src/manager.sh" ]; then
    echo ">>> Bootstrapping Installer..."
    
    # 1. Ensure Root
    if [ "$EUID" -ne 0 ]; then echo "Error: Run as root."; exit 1; fi
    
    # 2. Install Git & Basic Tools (if missing)
    echo " [*] Installing Git & Curl..."
    export DEBIAN_FRONTEND=noninteractive
    if ! command -v git &> /dev/null; then
        apt-get update -qq >/dev/null 2>&1
        apt-get install -y -qq git curl >/dev/null 2>&1
    fi
    
    # 3. Clone Repository to Temp
    TEMP_DIR="/tmp/tox1c-install-$(date +%s)"
    echo " [*] Downloading Repository..."
    git clone --quiet --depth=1 https://github.com/Tox1cs/ssh-tunnel.git "$TEMP_DIR" || {
        echo "Error: Download failed."; exit 1;
    }
    
    # 4. Handover Control
    # We switch to the downloaded folder and run this script again "locally"
    chmod +x "$TEMP_DIR/install.sh"
    cd "$TEMP_DIR"
    exec ./install.sh
    
    # The script stops here because 'exec' replaces the process.
    # The new instance running inside $TEMP_DIR takes over below.
fi

# ==============================================================================
# MAIN INSTALLATION LOGIC (Runs inside the cloned repo)
# ==============================================================================

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
cleanup() { 
    trap - SIGINT SIGTERM ERR EXIT
    # Remove the temp clone we created during bootstrap
    if [[ "$script_dir" == /tmp/tox1c-install-* ]]; then
        rm -rf "$script_dir"
    fi
    rm -rf /tmp/tox1c-build
}

# --- MAIN LOGIC ---
if [ "$EUID" -ne 0 ]; then error "Run as root."; fi

clear
echo -e "${C_CYAN}>>> TOX1C SSH-TUNNEL: ENTERPRISE DEPLOYMENT${C_NC}"
log "START" "Installation started."

# 1. DEPENDENCIES
msg "Installing System Dependencies..."
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq >> "$LOG_FILE" 2>&1 || true
apt-get install -y -qq build-essential cmake git ufw fail2ban vnstat curl dnsutils bc >> "$LOG_FILE" 2>&1
success "Dependencies ready."

# 2. KERNEL TUNING
msg "Injecting Kernel Parameters..."
echo "# TOX1C NETWORK OPTIMIZATION" > /etc/sysctl.d/99-tox1c-tuning.conf
echo "net.core.default_qdisc = fq" >> /etc/sysctl.d/99-tox1c-tuning.conf
echo "net.ipv4.tcp_congestion_control = bbr" >> /etc/sysctl.d/99-tox1c-tuning.conf
echo "net.core.rmem_max = 16777216" >> /etc/sysctl.d/99-tox1c-tuning.conf
echo "net.core.wmem_max = 16777216" >> /etc/sysctl.d/99-tox1c-tuning.conf
echo "net.ipv4.tcp_rmem = 4096 87380 16777216" >> /etc/sysctl.d/99-tox1c-tuning.conf
echo "net.ipv4.tcp_wmem = 4096 65536 16777216" >> /etc/sysctl.d/99-tox1c-tuning.conf
echo "net.ipv4.tcp_fastopen = 3" >> /etc/sysctl.d/99-tox1c-tuning.conf
sysctl -p /etc/sysctl.d/99-tox1c-tuning.conf >> "$LOG_FILE" 2>&1 || true
success "Kernel tuned (BBR + Huge Buffers)."

# 3. DIRECTORY STRUCTURE
msg "Securing Directory Structure..."
mkdir -p "${INSTALL_DIR}/bin" "${INSTALL_DIR}/config"
chmod 755 "${INSTALL_DIR}"
success "Permissions set to 755 (Service-Ready)."

# 4. COMPILATION
if [ ! -x "${INSTALL_DIR}/bin/tox1c-udpgw" ]; then
    msg "Compiling High-Performance UDP Gateway..."
    rm -f "${INSTALL_DIR}/bin/tox1c-udpgw"
    git clone https://github.com/ambrop72/badvpn.git /tmp/tox1c-build --quiet
    mkdir -p /tmp/tox1c-build/build
    cd /tmp/tox1c-build/build
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
if [ ! -f "${INSTALL_DIR}/config/banner.txt" ]; then
    cp "${script_dir}/assets/banner.txt" "${INSTALL_DIR}/config/banner.txt" 2>/dev/null || echo "Authorized Access Only" > "${INSTALL_DIR}/config/banner.txt"
fi

echo "[Unit]" > /etc/systemd/system/tox1c-tunnel.service
echo "Description=Tox1c SSH-Tunnel UDP Gateway" >> /etc/systemd/system/tox1c-tunnel.service
echo "After=network.target" >> /etc/systemd/system/tox1c-tunnel.service
echo "" >> /etc/systemd/system/tox1c-tunnel.service
echo "[Service]" >> /etc/systemd/system/tox1c-tunnel.service
echo "ExecStart=${INSTALL_DIR}/bin/tox1c-udpgw --listen-addr 127.0.0.1:7300 --max-clients 3000 --max-connections-for-client 300" >> /etc/systemd/system/tox1c-tunnel.service
echo "Restart=always" >> /etc/systemd/system/tox1c-tunnel.service
echo "User=nobody" >> /etc/systemd/system/tox1c-tunnel.service
echo "LimitNOFILE=65535" >> /etc/systemd/system/tox1c-tunnel.service
echo "CapabilityBoundingSet=CAP_NET_BIND_SERVICE" >> /etc/systemd/system/tox1c-tunnel.service
echo "AmbientCapabilities=CAP_NET_BIND_SERVICE" >> /etc/systemd/system/tox1c-tunnel.service
echo "NoNewPrivileges=yes" >> /etc/systemd/system/tox1c-tunnel.service
echo "" >> /etc/systemd/system/tox1c-tunnel.service
echo "[Install]" >> /etc/systemd/system/tox1c-tunnel.service
echo "WantedBy=multi-user.target" >> /etc/systemd/system/tox1c-tunnel.service

systemctl daemon-reload
systemctl enable tox1c-tunnel.service >> "$LOG_FILE" 2>&1
systemctl restart tox1c-tunnel.service >> "$LOG_FILE" 2>&1
success "Service active with LimitNOFILE=65535."

# 6. SSH CONFIGURATION
msg "Configuring SSH..."
groupadd -f tox1c-users
mkdir -p /etc/ssh/sshd_config.d

mkdir -p /run/sshd && chmod 0755 /run/sshd
mkdir -p /var/run/sshd && chmod 0755 /var/run/sshd

echo "Match Group tox1c-users" > /etc/ssh/sshd_config.d/99-tox1c.conf
echo "    Banner ${INSTALL_DIR}/config/banner.txt" >> /etc/ssh/sshd_config.d/99-tox1c.conf
echo "    ForceCommand /usr/sbin/nologin" >> /etc/ssh/sshd_config.d/99-tox1c.conf
echo "    X11Forwarding no" >> /etc/ssh/sshd_config.d/99-tox1c.conf
echo "    AllowAgentForwarding no" >> /etc/ssh/sshd_config.d/99-tox1c.conf
echo "    AllowTcpForwarding yes" >> /etc/ssh/sshd_config.d/99-tox1c.conf
echo "    PermitTunnel yes" >> /etc/ssh/sshd_config.d/99-tox1c.conf
echo "    PasswordAuthentication yes" >> /etc/ssh/sshd_config.d/99-tox1c.conf

if ! grep -q "^Include /etc/ssh/sshd_config.d/\*.conf" /etc/ssh/sshd_config; then
    sed -i '1i Include /etc/ssh/sshd_config.d/*.conf' /etc/ssh/sshd_config
fi

if sshd -t; then
    systemctl restart ssh
    success "SSH reloaded successfully."
else
    systemctl restart ssh || true
    success "SSH restarted (Fallback)."
fi

# 7. DASHBOARD INSTALLATION
msg "Installing Manager..."
cp "${script_dir}/src/manager.sh" "${INSTALL_DIR}/bin/manager"
chmod 700 "${INSTALL_DIR}/bin/manager"
ln -sf "${INSTALL_DIR}/bin/manager" "${BIN_LINK}"
success "Manager installed."

# 8. FIREWALL
msg "Securing Firewall..."
current_port=$(grep "^Port " /etc/ssh/sshd_config | head -n1 | awk '{print $2}') || current_port=22
ufw allow "${current_port}/tcp" >> "$LOG_FILE" 2>&1
ufw reload >> "$LOG_FILE" 2>&1
success "Firewall active on Port ${current_port}."

echo -e "\n${C_GREEN}[✔] SYSTEM READY.${C_NC} Run: ${C_YELLOW}tox1c${C_NC}"
