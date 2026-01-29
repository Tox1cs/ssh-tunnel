#!/bin/bash
# ==============================================================================
# INSTALLER: Tox1c SSH-Tunnel v2.2 (Patch 1)
# ==============================================================================
set -Eeuo pipefail
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

# --- CONFIG ---
INSTALL_PATH="/opt/tox1c-sshtunnel"
BIN_PATH="/usr/local/bin"
APP_COMMAND="tox1c"
REPO_NAME="Tox1c-SSHTunnel"

# --- STYLING ---
GREEN='\033[0;32m'; RED='\033[0;31m'; CYAN='\033[0;36m'; NC='\033[0m'
CHECK_MARK="${GREEN}✔${NC}"

if [[ $EUID -ne 0 ]]; then echo -e "${RED}[!] Error: Run as root.${NC}"; exit 1; fi

echo -e "${CYAN}>>> DEPLOYING ${REPO_NAME} v2.2...${NC}"
trap 'echo -e "${RED}[!] Setup Failed. Reverting...${NC}"; rm -rf /tmp/tox1c-build' ERR SIGINT

# 0. INTEGRITY CHECK
if [[ ! -f "$SCRIPT_DIR/assets/service.conf" ]]; then
    echo -e "${RED}[!] CRITICAL: Missing assets! Run git pull.${NC}"; exit 1
fi

# 1. DEPENDENCIES
echo -ne " [.] Installing Dependencies... "
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq >/dev/null 2>&1
apt-get install -y -qq build-essential cmake git ufw fail2ban vnstat curl >/dev/null 2>&1
echo -e "${CHECK_MARK}"

# 2. SYSTEM OPTIMIZATION (BBR)
echo -ne " [.] Enabling TCP BBR... "
if ! grep -q "net.core.default_qdisc=fq" /etc/sysctl.conf; then
    echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
    echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf
    sysctl -p >/dev/null 2>&1
fi
echo -e "${CHECK_MARK}"

# 3. SECURE DIRECTORY
echo -ne " [.] Creating Project Core... "
mkdir -p "${INSTALL_PATH}/bin" "${INSTALL_PATH}/config"
chmod 700 "${INSTALL_PATH}"
echo -e "${CHECK_MARK}"

# 4. COMPILE UDP GATEWAY
if [ ! -f "${INSTALL_PATH}/bin/tox1c-udpgw" ]; then
    echo -e " [.] Compiling High-Performance Gateway..."
    rm -rf /tmp/tox1c-build
    git clone https://github.com/ambrop72/badvpn.git /tmp/tox1c-build --quiet
    mkdir -p /tmp/tox1c-build/build
    cd /tmp/tox1c-build/build
    cmake .. -DBUILD_NOTHING_BY_DEFAULT=1 -DBUILD_UDPGW=1 >/dev/null 2>&1
    make install >/dev/null 2>&1
    cp udpgw/badvpn-udpgw "${INSTALL_PATH}/bin/tox1c-udpgw"
    chmod 755 "${INSTALL_PATH}/bin/tox1c-udpgw"
    cd /
    rm -rf /tmp/tox1c-build
    echo -e "     ${CHECK_MARK} Compiled."
else
    echo -e "     ${CHECK_MARK} Gateway Ready."
fi

# 5. DEPLOY CONFIGS
echo -ne " [.] Configuring Services... "
cp "$SCRIPT_DIR/assets/banner.txt" "${INSTALL_PATH}/config/banner.txt" 2>/dev/null || echo "Authorized Access Only" > "${INSTALL_PATH}/config/banner.txt"

cp "$SCRIPT_DIR/assets/service.conf" /etc/systemd/system/tox1c-tunnel.service
sed -i "s|EXEC_PATH|${INSTALL_PATH}/bin/tox1c-udpgw|g" /etc/systemd/system/tox1c-tunnel.service
systemctl daemon-reload
systemctl enable --now tox1c-tunnel.service >/dev/null 2>&1

groupadd -f tox1c-users
cat <<EOF > /etc/ssh/sshd_config.d/99-tox1c.conf
Match Group tox1c-users
    Banner ${INSTALL_PATH}/config/banner.txt
    ForceCommand /usr/sbin/nologin
    X11Forwarding no
    AllowAgentForwarding no
    AllowTcpForwarding yes
    PermitTunnel yes
    PasswordAuthentication yes
EOF
systemctl restart ssh
echo -e "${CHECK_MARK}"

# 6. INSTALL MANAGER APP
echo -ne " [.] Installing Dashboard... "
cp "$SCRIPT_DIR/src/manager.sh" "${INSTALL_PATH}/bin/manager"
chmod 700 "${INSTALL_PATH}/bin/manager"
ln -sf "${INSTALL_PATH}/bin/manager" "${BIN_PATH}/${APP_COMMAND}"
echo -e "${CHECK_MARK}"

# 7. FIREWALL (Smart Port Detection - FIX)
echo -ne " [.] Securing Firewall... "

# FIX: Added '|| true' to prevent script crash if grep finds nothing
CURRENT_SSH_PORT=$(grep "^Port " /etc/ssh/sshd_config | head -n1 | cut -d' ' -f2 || true)

# If variable is empty (grep failed), default to 22
if [[ -z "$CURRENT_SSH_PORT" ]]; then 
    CURRENT_SSH_PORT=22 
fi

ufw allow "${CURRENT_SSH_PORT}/tcp" >/dev/null 2>&1
ufw reload >/dev/null 2>&1
echo -e "${CHECK_MARK}"

echo ""
echo -e "${GREEN}===================================================${NC}"
echo -e "${GREEN}   INSTALLED SUCCESSFULLY${NC}"
echo -e "   Command: ${CYAN}${APP_COMMAND}${NC}"
echo -e "${GREEN}===================================================${NC}"
