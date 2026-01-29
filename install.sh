#!/bin/bash
# ==============================================================================
# INSTALLER: Tox1c SSH-Tunnel (Professional Edition)
# ==============================================================================
set -Eeuo pipefail

# --- CONFIGURATION ---
INSTALL_PATH="/opt/tox1c-sshtunnel"
BIN_PATH="/usr/local/bin"
APP_COMMAND="tox1c"
REPO_NAME="Tox1c-SSHTunnel"

# --- STYLING ---
GREEN='\033[0;32m'; RED='\033[0;31m'; CYAN='\033[0;36m'; NC='\033[0m'
CHECK_MARK="${GREEN}✔${NC}"

# --- ROOT CHECK ---
if [[ $EUID -ne 0 ]]; then echo -e "${RED}[!] Error: This script must be run as root.${NC}"; exit 1; fi

echo -e "${CYAN}>>> DEPLOYING ${REPO_NAME}...${NC}"

# TRAP: Cleanup if failed
trap 'echo -e "${RED}[!] Setup Failed. Reverting...${NC}"; rm -rf /tmp/tox1c-build' ERR SIGINT

# 1. DEPENDENCIES
echo -ne " [.] Installing Dependencies... "
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq >/dev/null 2>&1
apt-get install -y -qq build-essential cmake git ufw fail2ban vnstat curl >/dev/null 2>&1
echo -e "${CHECK_MARK}"

# 2. SECURE DIRECTORY
echo -ne " [.] Creating Project Core at ${INSTALL_PATH}... "
mkdir -p "${INSTALL_PATH}/bin" "${INSTALL_PATH}/config"
# SECURE: Only root can access this folder
chmod 700 "${INSTALL_PATH}"
echo -e "${CHECK_MARK}"

# 3. COMPILE UDP GATEWAY
if [ ! -f "${INSTALL_PATH}/bin/tox1c-udpgw" ]; then
    echo -e " [.] Compiling High-Performance UDP Gateway..."
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
    echo -e "     ${CHECK_MARK} Compilation Success."
else
    echo -e "     ${CHECK_MARK} Gateway already installed."
fi

# 4. DEPLOY ASSETS & CONFIG
echo -ne " [.] Configuring Services... "

# -- 4a. Banner --
if [ -f "assets/banner.txt" ]; then
    cp assets/banner.txt "${INSTALL_PATH}/config/banner.txt"
else
    echo "Authorized Access Only" > "${INSTALL_PATH}/config/banner.txt"
fi

# -- 4b. Systemd Service --
cp assets/service.conf /etc/systemd/system/tox1c-tunnel.service
sed -i "s|EXEC_PATH|${INSTALL_PATH}/bin/tox1c-udpgw|g" /etc/systemd/system/tox1c-tunnel.service
systemctl daemon-reload
systemctl enable --now tox1c-tunnel.service >/dev/null 2>&1

# -- 4c. SSH Group Isolation --
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

# 5. INSTALL MANAGER APP
echo -ne " [.] Installing CLI Dashboard... "
cp src/manager.sh "${INSTALL_PATH}/bin/manager"
chmod 700 "${INSTALL_PATH}/bin/manager"
ln -sf "${INSTALL_PATH}/bin/manager" "${BIN_PATH}/${APP_COMMAND}"
echo -e "${CHECK_MARK}"

# 6. FIREWALL
echo -ne " [.] Securing Firewall... "
ufw allow 22/tcp >/dev/null 2>&1
ufw reload >/dev/null 2>&1
echo -e "${CHECK_MARK}"

echo ""
echo -e "${GREEN}===================================================${NC}"
echo -e "${GREEN}   INSTALLED SUCCESSFULLY${NC}"
echo -e "   Command to run: ${CYAN}${APP_COMMAND}${NC}"
echo -e "${GREEN}===================================================${NC}"
