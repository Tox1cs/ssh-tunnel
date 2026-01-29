#!/bin/bash
# ==============================================================================
# MANAGER: TOX1C SSH-TUNNEL
# ==============================================================================

# CONFIG
VPN_GROUP="tox1c-users"
UDPGW_PORT="7300"
VERSION="2.0-PRO"

# THEME
CYAN='\033[0;36m'; GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[1;33m'; WHITE='\033[1;37m'; NC='\033[0m'

# --- SECURITY CHECKS ---
check_root() { [[ $EUID -ne 0 ]] && { echo -e "${RED}[!] Run as root.${NC}"; exit 1; } }

validate_input() {
    # Regex: Alphanumeric, underscores, dashes only
    if [[ ! "$1" =~ ^[a-zA-Z0-9_-]+$ ]]; then
        echo -e "${RED}[!] Error: Invalid characters. Use A-Z, 0-9, -, _ only.${NC}"
        pause; return 1
    fi
    return 0
}

# --- UI ---
header() {
    clear
    echo -e "${CYAN}╔══════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║              ${WHITE}TOX1C SSH-TUNNEL ${YELLOW}v${VERSION}${CYAN}                   ║${NC}"
    echo -e "${CYAN}╠══════════════════════════════════════════════════════╣${NC}"
    echo -e "${CYAN}║${NC}  GitHub: ${CYAN}https://github.com/Tox1cs${NC}                   ${CYAN}║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════╝${NC}"
    echo -e " ${YELLOW}System:${NC} $(hostname) | ${YELLOW}IP:${NC} $(curl -s --connect-timeout 2 ifconfig.me)"
    echo -e "${CYAN}──────────────────────────────────────────────────────${NC}"
}

pause() { echo ""; read -rsn1 -p "Press any key to return..."; }

# --- ACTIONS ---
create_user() {
    header
    echo -e "${GREEN}[+] ADD NEW TUNNEL USER${NC}"
    read -p "Username: " u
    validate_input "$u" || return
    
    if id "$u" &>/dev/null; then echo -e "${RED}[!] User exists.${NC}"; pause; return; fi

    read -p "Password (Enter for Random): " p
    if [[ -z "$p" ]]; then p=$(openssl rand -base64 12); fi
    
    useradd -m -s /usr/sbin/nologin -G "$VPN_GROUP" "$u"
    echo "$u:$p" | chpasswd
    
    echo -e "\n${GREEN}✔ User Created Securely.${NC}"
    echo -e "User: ${WHITE}$u${NC}\nPass: ${WHITE}$p${NC}\nUDPGW: 127.0.0.1:${UDPGW_PORT}"
    pause
}

remove_user() {
    header
    echo -e "${RED}[-] REMOVE TUNNEL USER${NC}"
    # Only list users in the VPN group, hide empty lines
    grep "$VPN_GROUP" /etc/group | cut -d: -f4 | tr ',' '\n' | sed '/^$/d' | sed 's/^/ - /'
    echo ""
    read -p "Username to delete: " u
    validate_input "$u" || return
    
    if id -nG "$u" 2>/dev/null | grep -qw "$VPN_GROUP"; then
        pkill -u "$u"
        userdel -r "$u"
        echo -e "${GREEN}✔ User deleted and disconnected.${NC}"
    else
        echo -e "${RED}[!] User not found in $VPN_GROUP.${NC}"
    fi
    pause
}

monitor() {
    header
    echo -e "${YELLOW}[*] LIVE TRAFFIC MONITOR (Ctrl+C to Stop)${NC}"
    echo -e "Checking Gateway Service..."
    systemctl is-active --quiet tox1c-tunnel.service && echo -e "${GREEN}● UDPGW Active${NC}" || echo -e "${RED}● UDPGW Failed${NC}"
    echo "---------------------------------"
    watch -n 1 -c "ps -eo user,cmd | grep 'sshd: ' | grep -v 'root' | grep -v 'grep'; echo ''; vnstat -tr 2"
}

# --- MAIN ---
check_root
while true; do
    header
    echo " 1) Create User"
    echo " 2) Remove User"
    echo " 3) Monitor System"
    echo " 0) Exit"
    read -p " Select: " opt
    case $opt in
        1) create_user ;;
        2) remove_user ;;
        3) monitor ;;
        0) exit ;;
    esac
done
