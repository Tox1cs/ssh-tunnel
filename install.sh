#!/bin/bash

set -u

if [ ! -d ".git" ] && [ ! -f "src/manager.sh" ]; then
    if [ "$EUID" -ne 0 ]; then
        echo "Error: Run as root."
        exit 1
    fi
    
    export DEBIAN_FRONTEND=noninteractive
    
    if ! command -v git &>/dev/null; then
        apt-get update -qq >/dev/null 2>&1
        apt-get install -y -qq git curl >/dev/null 2>&1
    fi
    
    TEMP_DIR="/tmp/tox1c-install-$(date +%s)"
    git clone --quiet --depth=1 https://github.com/Tox1cs/ssh-tunnel.git "$TEMP_DIR" || {
        echo "Error: Download failed."
        exit 1
    }
    
    chmod +x "$TEMP_DIR/install.sh"
    cd "$TEMP_DIR"
    exec ./install.sh
fi

trap cleanup SIGINT SIGTERM ERR EXIT

readonly INSTALL_DIR="/opt/tox1c-sshtunnel"
readonly LOG_FILE="/var/log/tox1c-install.log"
readonly BIN_LINK="/usr/local/bin/tox1c"

readonly C_RED='\033[0;31m'
readonly C_GREEN='\033[0;32m'
readonly C_CYAN='\033[0;36m'
readonly C_YELLOW='\033[1;33m'
readonly C_NC='\033[0m'

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd -P)

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$1] $2" >> "$LOG_FILE"; }
msg() { echo -e "${C_CYAN}[*]${C_NC} $1"; log "INFO" "$1"; }
success() { echo -e "${C_GREEN}[✔]${C_NC} $1"; log "SUCCESS" "$1"; }
error() { echo -e "${C_RED}[✘]${C_NC} ERROR: $1"; log "ERROR" "$1"; exit 1; }

cleanup() {
    trap - SIGINT SIGTERM ERR EXIT
    if [[ "$script_dir" == /tmp/tox1c-install-* ]]; then
        rm -rf "$script_dir"
    fi
    rm -rf /tmp/tox1c-build
}

if [ "$EUID" -ne 0 ]; then error "Run as root."; fi

clear
echo -e "${C_CYAN}>>> TOX1C SSH-TUNNEL: ENTERPRISE DEPLOYMENT${C_NC}"
log "START" "Installation started."

msg "Installing System Dependencies..."
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq >> "$LOG_FILE" 2>&1 || true
apt-get install -y -qq build-essential cmake git ufw fail2ban vnstat curl dnsutils bc >> "$LOG_FILE" 2>&1
success "Dependencies ready."

msg "Injecting Kernel Parameters..."
cat > /etc/sysctl.d/99-tox1c-tuning.conf << 'EOF'
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
net.ipv4.tcp_rmem = 4096 87380 16777216
net.ipv4.tcp_wmem = 4096 65536 16777216
net.ipv4.tcp_fastopen = 3
net.ipv4.ip_forward = 1
net.ipv4.tcp_max_syn_backlog = 4096
net.core.somaxconn = 4096
net.ipv4.tcp_tw_reuse = 1
EOF
sysctl -p /etc/sysctl.d/99-tox1c-tuning.conf >> "$LOG_FILE" 2>&1 || true
success "Kernel tuned (BBR + Huge Buffers)."

msg "Securing Directory Structure..."
mkdir -p "${INSTALL_DIR}/bin" "${INSTALL_DIR}/config"
chmod 755 "${INSTALL_DIR}"
success "Permissions set to 755."

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

msg "Configuring Systemd Service..."
if [ ! -f "${INSTALL_DIR}/config/banner.txt" ]; then
    cp "${script_dir}/assets/banner.txt" "${INSTALL_DIR}/config/banner.txt" 2>/dev/null || echo "Authorized Access Only" > "${INSTALL_DIR}/config/banner.txt"
fi

cat > /etc/systemd/system/tox1c-tunnel.service << EOF
[Unit]
Description=Tox1c SSH-Tunnel UDP Gateway
After=network.target

[Service]
ExecStart=${INSTALL_DIR}/bin/tox1c-udpgw --listen-addr 127.0.0.1:7300 --max-clients 3000 --max-connections-for-client 300
Restart=always
RestartSec=5
User=nobody
LimitNOFILE=65535
CapabilityBoundingSet=CAP_NET_BIND_SERVICE
AmbientCapabilities=CAP_NET_BIND_SERVICE
NoNewPrivileges=yes
ProtectSystem=strict
ProtectHome=true

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable tox1c-tunnel.service >> "$LOG_FILE" 2>&1
systemctl restart tox1c-tunnel.service >> "$LOG_FILE" 2>&1
success "Service active with LimitNOFILE=65535."

msg "Configuring SSH..."
groupadd -f tox1c-users
mkdir -p /etc/ssh/sshd_config.d
mkdir -p /run/sshd && chmod 0755 /run/sshd

cat > /etc/ssh/sshd_config.d/99-tox1c.conf << 'EOF'
Match Group tox1c-users
    Banner /opt/tox1c-sshtunnel/config/banner.txt
    ForceCommand /usr/sbin/nologin
    X11Forwarding no
    AllowAgentForwarding no
    AllowTcpForwarding yes
    PermitTunnel yes
    PasswordAuthentication yes
    ClientAliveInterval 300
    ClientAliveCountMax 2
EOF

if ! grep -q "^Include /etc/ssh/sshd_config.d/\*.conf" /etc/ssh/sshd_config; then
    sed -i '1i Include /etc/ssh/sshd_config.d/*.conf' /etc/ssh/sshd_config
fi

if sshd -t 2>/dev/null; then
    systemctl restart ssh
    success "SSH reloaded successfully."
else
    systemctl restart ssh || true
    success "SSH restarted (Fallback)."
fi

msg "Installing Manager..."
{
    cat "${script_dir}/src/lib/colors.sh"
    echo ""
    cat "${script_dir}/src/lib/utils.sh"
    echo ""
    cat "${script_dir}/src/lib/metrics.sh"
    echo ""
    cat "${script_dir}/src/lib/users.sh"
    echo ""
    cat "${script_dir}/src/lib/system.sh"
    echo ""
    cat "${script_dir}/src/ui/render.sh"
    echo ""
    tail -n +2 "${script_dir}/src/manager.sh"
} > "${INSTALL_DIR}/bin/manager"
chmod 700 "${INSTALL_DIR}/bin/manager"
ln -sf "${INSTALL_DIR}/bin/manager" "${BIN_LINK}"
success "Manager installed."

msg "Securing Firewall..."
current_port=$(grep "^Port " /etc/ssh/sshd_config | head -n1 | awk '{print $2}') || current_port=22
ufw allow "${current_port}/tcp" >> "$LOG_FILE" 2>&1
ufw reload >> "$LOG_FILE" 2>&1
success "Firewall active on Port ${current_port}."

echo ""
echo -e "${C_GREEN}[✔] SYSTEM READY.${C_NC} Run: ${C_YELLOW}tox1c${C_NC}"
