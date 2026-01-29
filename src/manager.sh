#!/bin/bash
# ==============================================================================
# MANAGER: TOX1C SSH-TUNNEL v2.2
# ==============================================================================

# CONFIG
VPN_GROUP="tox1c-users"
UDPGW_PORT="7300"
VERSION="2.2"

# THEME
CYAN='\033[0;36m'; GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[1;33m'; WHITE='\033[1;37m'; NC='\033[0m'
GRAY='\033[1;30m'

# --- SECURITY ---
check_root() { [[ $EUID -ne 0 ]] && { echo -e "${RED}[!] Run as root.${NC}"; exit 1; } }

validate_input() {
    if [[ ! "$1" =~ ^[a-zA-Z0-9_-]+$ ]]; then
        echo -e "${RED}[!] Error: Invalid characters.${NC}"; pause; return 1
    fi
    return 0
}

# --- UI ---
header() {
    clear
    echo -e "${CYAN}╔══════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${WHITE}                   TOX1C SSH-TUNNEL                   ${CYAN}║${NC}"
    echo -e "${CYAN}╠══════════════════════════════════════════════════════╣${NC}"
    echo -e "${CYAN}║${NC}  GitHub: ${CYAN}https://github.com/Tox1cs${NC}                   ${CYAN}║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════╝${NC}"
    
    HOST=$(hostname)
    IP=$(curl -s --connect-timeout 2 ifconfig.me)
    # Get Current SSH Port
    SSH_PORT=$(grep "^Port " /etc/ssh/sshd_config | head -n1 | cut -d' ' -f2)
    [[ -z "$SSH_PORT" ]] && SSH_PORT=22

    echo -e " ${YELLOW}Host:${NC} $HOST  |  ${YELLOW}IP:${NC} $IP"
    
    # BBR Check
    if sysctl net.ipv4.tcp_congestion_control | grep -q "bbr"; then
        MODE="${GREEN}Turbo (BBR)${NC}"
    else
        MODE="${GRAY}Standard${NC}"
    fi
    echo -e " ${YELLOW}Mode:${NC} $MODE  |  ${YELLOW}Port:${NC} ${GREEN}$SSH_PORT${NC}"
    echo -e "${CYAN}──────────────────────────────────────────────────────${NC}"
}

pause() { echo ""; read -rsn1 -p "Press any key to return..."; }

# --- USER MANAGEMENT ---
create_user() {
    header
    echo -e "${GREEN}[+] CREATE USER${NC}"
    read -p "Username: " u
    validate_input "$u" || return
    
    if id "$u" &>/dev/null; then echo -e "${RED}[!] User exists.${NC}"; pause; return; fi

    read -p "Password (Random): " p
    [[ -z "$p" ]] && p=$(openssl rand -base64 12)
    
    read -p "Expiry Days (30): " days
    [[ -z "$days" ]] && days=30
    
    useradd -m -s /usr/sbin/nologin -G "$VPN_GROUP" "$u"
    echo "$u:$p" | chpasswd
    EXP_DATE=$(date -d "+$days days" +%Y-%m-%d)
    chage -E "$EXP_DATE" "$u"
    
    echo -e "\n${GREEN}✔ User Created.${NC}"
    echo -e "User:    ${WHITE}$u${NC}"
    echo -e "Pass:    ${WHITE}$p${NC}"
    echo -e "Expires: ${YELLOW}$EXP_DATE${NC}"
    pause
}

remove_user() {
    header
    echo -e "${RED}[-] DELETE USER${NC}"
    grep "$VPN_GROUP" /etc/group | cut -d: -f4 | tr ',' '\n' | sed '/^$/d' | sed 's/^/ - /'
    echo ""
    read -p "Username: " u
    validate_input "$u" || return
    
    if id -nG "$u" 2>/dev/null | grep -qw "$VPN_GROUP"; then
        pkill -u "$u"
        userdel -r "$u"
        echo -e "${GREEN}✔ Deleted.${NC}"
    else
        echo -e "${RED}[!] Not found.${NC}"
    fi
    pause
}

lock_unlock_user() {
    header
    echo -e "${YELLOW}[!] LOCK / UNLOCK USER${NC}"
    echo -e "${GRAY}Locked users cannot connect but data is saved.${NC}"
    echo ""
    # List users with Lock Status (L = Locked, P = Password set)
    for u in $(grep "$VPN_GROUP" /etc/group | cut -d: -f4 | tr ',' '\n'); do
        if [[ -n "$u" ]]; then
            STATUS=$(passwd -S "$u" | awk '{print $2}')
            [[ "$STATUS" == "L" ]] && STATE="${RED}LOCKED${NC}" || STATE="${GREEN}ACTIVE${NC}"
            echo -e " - ${WHITE}$u${NC} [$STATE]"
        fi
    done
    echo ""
    read -p "Username: " u
    validate_input "$u" || return

    if ! id -nG "$u" 2>/dev/null | grep -qw "$VPN_GROUP"; then
        echo -e "${RED}[!] Not a VPN user.${NC}"; pause; return
    fi

    # Check status and toggle
    STATUS=$(passwd -S "$u" | awk '{print $2}')
    if [[ "$STATUS" == "L" ]]; then
        passwd -u "$u" >/dev/null 2>&1
        echo -e "${GREEN}✔ User Unlocked.${NC}"
    else
        passwd -l "$u" >/dev/null 2>&1
        pkill -u "$u"
        echo -e "${RED}✔ User Locked & Disconnected.${NC}"
    fi
    pause
}

# --- SYSTEM SETTINGS ---
change_port() {
    header
    echo -e "${YELLOW}[!] STEALTH MODE: CHANGE SSH PORT${NC}"
    echo -e "${GRAY}Current Port: $SSH_PORT${NC}"
    echo -e "${RED}WARNING: Ensure you update your VPN client port!${NC}"
    echo ""
    read -p "New Port (e.g. 2082): " new_p
    
    if [[ ! "$new_p" =~ ^[0-9]+$ ]] || [ "$new_p" -lt 1 ] || [ "$new_p" -gt 65535 ]; then
        echo -e "${RED}[!] Invalid Port.${NC}"; pause; return
    fi

    echo -e "\n${YELLOW}[*] Updating configuration...${NC}"
    
    # 1. Update SSH Config (Safe Regex)
    # Check if Port line exists, replace it. If not, append it.
    if grep -q "^Port " /etc/ssh/sshd_config; then
        sed -i "s/^Port .*/Port $new_p/" /etc/ssh/sshd_config
    else
        echo "Port $new_p" >> /etc/ssh/sshd_config
    fi

    # 2. Update Firewall
    ufw allow "$new_p"/tcp >/dev/null
    ufw delete allow "$SSH_PORT"/tcp >/dev/null 2>&1
    ufw reload >/dev/null

    # 3. Restart SSH
    systemctl restart ssh
    
    echo -e "${GREEN}✔ SUCCESS! SSH is now on Port $new_p.${NC}"
    echo -e "Reconnect your SSH client using the new port."
    pause
}

monitor() {
    header
    echo -e "${YELLOW}[*] LIVE MONITOR (Ctrl+C to Stop)${NC}"
    systemctl is-active --quiet tox1c-tunnel.service && echo -e "${GREEN}● Gateway Active${NC}" || echo -e "${RED}● Gateway Failed${NC}"
    echo "---------------------------------"
    watch -n 1 -c "ps -eo user,cmd | grep 'sshd: ' | grep -v 'root' | grep -v 'grep'; echo ''; vnstat -tr 2"
}

# --- MENUS ---
menu_users() {
    while true; do
        header
        echo " 1) Create User"
        echo " 2) Remove User"
        echo " 3) Lock/Unlock User"
        echo " 0) Back"
        read -p " Select: " o
        case $o in
            1) create_user ;;
            2) remove_user ;;
            3) lock_unlock_user ;;
            0) return ;;
        esac
    done
}

menu_system() {
    while true; do
        header
        echo " 1) Change SSH Port (Stealth)"
        echo " 2) Monitor Traffic"
        echo " 0) Back"
        read -p " Select: " o
        case $o in
            1) change_port ;;
            2) monitor ;;
            0) return ;;
        esac
    done
}

# --- MAIN ---
check_root
while true; do
    header
    echo " 1) User Management"
    echo " 2) System Settings"
    echo " 0) Exit"
    read -p " Select: " opt
    case $opt in
        1) menu_users ;;
        2) menu_system ;;
        0) exit ;;
    esac
done
