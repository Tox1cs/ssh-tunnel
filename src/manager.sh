#!/bin/bash
# ==============================================================================
# MANAGER: TOX1C SSH-TUNNEL (DEV BRANCH)
# ==============================================================================

# CONFIG
VPN_GROUP="tox1c-users"
UDPGW_PORT="7300"
VERSION="2.3-dev"
GITHUB_REPO="Tox1cs/ssh-tunnel"
BRANCH="dev"  # We are testing on DEV branch

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
    # Added Version in GRAY to make it look "small" and subtle
    echo -e "${CYAN}║${NC}  GitHub: ${CYAN}https://github.com/${GITHUB_REPO}${NC}     ${GRAY}${VERSION}${NC}  ${CYAN}║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════╝${NC}"
    
    HOST=$(hostname)
    IP=$(curl -s --connect-timeout 2 ifconfig.me)
    SSH_PORT=$(grep "^Port " /etc/ssh/sshd_config | head -n1 | cut -d' ' -f2 || echo "22")
    
    if sysctl net.ipv4.tcp_congestion_control | grep -q "bbr"; then
        MODE="${GREEN}Turbo (BBR)${NC}"
    else
        MODE="${GRAY}Standard${NC}"
    fi

    echo -e " ${YELLOW}Host:${NC} $HOST  |  ${YELLOW}IP:${NC} $IP"
    echo -e " ${YELLOW}Mode:${NC} $MODE  |  ${YELLOW}Port:${NC} ${GREEN}$SSH_PORT${NC}"
    echo -e "${CYAN}──────────────────────────────────────────────────────${NC}"
}

pause() { echo ""; read -rsn1 -p "Press any key to return..."; }

# --- CORE FUNCTIONS ---

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

    STATUS=$(passwd -S "$u" | awk '{print $2}')
    if [[ "$STATUS" == "L" ]]; then
        passwd -u "$u" >/dev/null 2>&1
        echo -e "${GREEN}✔ User Unlocked.${NC}"
    else
        passwd -l "$u" >/dev/null 2>&1
        pkill -u "$u"
        echo -e "${RED}✔ User Locked.${NC}"
    fi
    pause
}

change_port() {
    header
    echo -e "${YELLOW}[!] STEALTH MODE: CHANGE PORT${NC}"
    echo -e "Current: $SSH_PORT"
    read -p "New Port: " new_p
    
    if [[ ! "$new_p" =~ ^[0-9]+$ ]] || [ "$new_p" -lt 1 ] || [ "$new_p" -gt 65535 ]; then
        echo -e "${RED}[!] Invalid Port.${NC}"; pause; return
    fi

    echo -e "\n${YELLOW}[*] Updating...${NC}"
    if grep -q "^Port " /etc/ssh/sshd_config; then
        sed -i "s/^Port .*/Port $new_p/" /etc/ssh/sshd_config
    else
        echo "Port $new_p" >> /etc/ssh/sshd_config
    fi

    ufw allow "$new_p"/tcp >/dev/null
    ufw delete allow "$SSH_PORT"/tcp >/dev/null 2>&1
    ufw reload >/dev/null
    systemctl restart ssh
    
    echo -e "${GREEN}✔ Success! Port changed to $new_p.${NC}"
    pause
}

monitor() {
    header
    echo -e "${YELLOW}[*] LIVE MONITOR (Ctrl+C to Stop)${NC}"
    watch -n 1 -c "ps -eo user,cmd | grep 'sshd: ' | grep -v 'root' | grep -v 'grep'; echo ''; vnstat -tr 2"
}

# --- UPDATE ENGINE (DEV) ---
update_system() {
    header
    echo -e "${YELLOW}[*] SYSTEM UPDATE (DEV BRANCH)${NC}"
    echo -e "This will pull the latest code from the '${BRANCH}' branch."
    read -p "Continue? (y/n): " confirm
    [[ "$confirm" != "y" ]] && return

    echo -e "\n${CYAN}>>> Connecting to GitHub...${NC}"
    
    TMP_DIR="/tmp/tox1c_updater"
    rm -rf "$TMP_DIR"
    
    # Clone the DEV branch specifically
    if git clone -b "$BRANCH" "https://github.com/${GITHUB_REPO}.git" "$TMP_DIR"; then
        echo -e "${GREEN}✔ Download Complete.${NC}"
        echo -e "Installing Update..."
        
        chmod +x "$TMP_DIR/install.sh"
        
        # Run the installer from the temp dir
        # We use bash explicitly to avoid permission issues
        (cd "$TMP_DIR" && bash install.sh)
        
        rm -rf "$TMP_DIR"
        echo -e "\n${GREEN}✔ UPDATE SUCCESSFUL! Restarting...${NC}"
        sleep 2
        exec "$0"
    else
        echo -e "${RED}[!] Error: Could not connect to GitHub.${NC}"
        echo -e "Check your internet connection or git installation."
        pause
    fi
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
        echo " 1) Change SSH Port"
        echo " 2) Monitor Traffic"
        echo " 8) Update System (Dev)"
        echo " 0) Back"
        read -p " Select: " o
        case $o in
            1) change_port ;;
            2) monitor ;;
            8) update_system ;;
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
