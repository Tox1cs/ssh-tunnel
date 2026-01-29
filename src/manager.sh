#!/bin/bash
# ==============================================================================
# MANAGER: TOX1C SSH-TUNNEL | DASHBOARD
# ==============================================================================

# --- CONFIGURATION ---
readonly VPN_GROUP="tox1c-users"
readonly VERSION="2.3-PRO"
readonly REPO="Tox1cs/ssh-tunnel"
readonly BRANCH="main" # Set to 'main' for release, 'dev' for testing

# --- COLORS ---
readonly C_RED='\033[0;31m'
readonly C_GREEN='\033[0;32m'
readonly C_YELLOW='\033[1;33m'
readonly C_BLUE='\033[0;34m'
readonly C_CYAN='\033[0;36m'
readonly C_GRAY='\033[1;30m'
readonly C_NC='\033[0m'

# --- UTILS ---

pause() {
    echo ""
    read -rsn1 -p "Press any key to return..."
    echo ""
}

validate_input() {
    if [[ ! "$1" =~ ^[a-zA-Z0-9_-]+$ ]]; then
        echo -e "${C_RED}[!] Error: Invalid characters.${C_NC}"
        pause
        return 1
    fi
    return 0
}

# --- UI RENDERING ---

draw_header() {
    clear
    local title="TOX1C SSH-TUNNEL"
    local repo_url="github.com/${REPO}"
    
    # Dynamic Hardware Info
    local host=$(hostname)
    local ip=$(curl -s --connect-timeout 2 ifconfig.me || echo "Offline")
    local port=$(grep "^Port " /etc/ssh/sshd_config | head -n1 | awk '{print $2}' || echo "22")
    
    # BBR Check
    local mode="${C_GRAY}Standard${C_NC}"
    if sysctl net.ipv4.tcp_congestion_control | grep -q "bbr"; then
        mode="${C_GREEN}Turbo (BBR)${C_NC}"
    fi

    # The Box (Width 60)
    echo -e "${C_CYAN}╔══════════════════════════════════════════════════════════════╗${C_NC}"
    
    # Title Centering
    printf "${C_CYAN}║${C_NC}%*s${C_CYAN}║${C_NC}\n" 60 "$(printf "%*s%s%*s" 20 "" "$title" 22 "")"
    
    echo -e "${C_CYAN}╠══════════════════════════════════════════════════════════════╣${C_NC}"
    
    # Repo & Version Line
    # We use printf to ensure the right alignment relative to the border
    # Border (1) + Space (2) + Label (8) + URL + Padding + Version + Space + Border (1)
    # Total inner width is 60 chars
    
    # Calculate padding
    local inner_width=60
    local line_content="  GitHub: ${repo_url}"
    local ver_content="v${VERSION}  "
    local padding=$((inner_width - ${#line_content} - ${#ver_content}))
    
    printf "${C_CYAN}║${C_NC}%s%*s${C_GRAY}%s${C_NC}${C_CYAN}║${C_NC}\n" "$line_content" $padding "" "$ver_content"

    echo -e "${C_CYAN}╚══════════════════════════════════════════════════════════════╝${C_NC}"
    
    # Status Bar
    echo -e " ${C_YELLOW}HOST:${C_NC} $host   ${C_YELLOW}IP:${C_NC} $ip"
    echo -e " ${C_YELLOW}MODE:${C_NC} $mode   ${C_YELLOW}PORT:${C_NC} $port"
    echo -e "${C_CYAN}──────────────────────────────────────────────────────────────${C_NC}"
}

# --- FUNCTIONS ---

create_user() {
    draw_header
    echo -e "${C_GREEN}[+] CREATE NEW USER${C_NC}"
    read -p "Username: " u
    validate_input "$u" || return
    
    if id "$u" &>/dev/null; then echo -e "${C_RED}[!] User already exists.${C_NC}"; pause; return; fi

    read -p "Password (Enter for Random): " p
    [[ -z "$p" ]] && p=$(openssl rand -base64 12)
    
    read -p "Expiry Days (Default 30): " days
    [[ -z "$days" ]] && days=30
    
    useradd -m -s /usr/sbin/nologin -G "$VPN_GROUP" "$u"
    echo "$u:$p" | chpasswd
    
    local exp_date=$(date -d "+$days days" +%Y-%m-%d)
    chage -E "$exp_date" "$u"
    
    echo -e "\n${C_GREEN}✔ User Created Successfully.${C_NC}"
    echo -e "Username: ${C_YELLOW}$u${C_NC}"
    echo -e "Password: ${C_YELLOW}$p${C_NC}"
    echo -e "Expires:  ${C_YELLOW}$exp_date${C_NC}"
    pause
}

remove_user() {
    draw_header
    echo -e "${C_RED}[-] REMOVE USER${C_NC}"
    echo -e "${C_GRAY}Active Users:${C_NC}"
    grep "$VPN_GROUP" /etc/group | cut -d: -f4 | tr ',' '\n' | sed '/^$/d' | sed 's/^/ - /'
    echo ""
    read -p "Username to delete: " u
    validate_input "$u" || return
    
    if id -nG "$u" 2>/dev/null | grep -qw "$VPN_GROUP"; then
        pkill -u "$u"
        userdel -r "$u"
        echo -e "${C_GREEN}✔ User deleted.${C_NC}"
    else
        echo -e "${C_RED}[!] User not found in VPN group.${C_NC}"
    fi
    pause
}

lock_unlock() {
    draw_header
    echo -e "${C_YELLOW}[!] LOCK / UNLOCK ACCESS${C_NC}"
    
    local user_list=$(grep "$VPN_GROUP" /etc/group | cut -d: -f4 | tr ',' '\n')
    for u in $user_list; do
        [[ -z "$u" ]] && continue
        local status=$(passwd -S "$u" | awk '{print $2}')
        local state="${C_GREEN}ACTIVE${C_NC}"
        [[ "$status" == "L" ]] && state="${C_RED}LOCKED${C_NC}"
        echo -e " - ${C_YELLOW}$u${C_NC} [$state]"
    done
    
    echo ""
    read -p "Username: " u
    validate_input "$u" || return

    if ! id -nG "$u" 2>/dev/null | grep -qw "$VPN_GROUP"; then
        echo -e "${C_RED}[!] Not a VPN user.${C_NC}"; pause; return
    fi

    local status=$(passwd -S "$u" | awk '{print $2}')
    if [[ "$status" == "L" ]]; then
        passwd -u "$u" >/dev/null 2>&1
        echo -e "${C_GREEN}✔ User Unlocked.${C_NC}"
    else
        passwd -l "$u" >/dev/null 2>&1
        pkill -u "$u"
        echo -e "${C_RED}✔ User Locked & Sessions Killed.${C_NC}"
    fi
    pause
}

system_update() {
    draw_header
    echo -e "${C_YELLOW}[*] SYSTEM UPDATE${C_NC}"
    echo -e "Checking for updates from Branch: ${C_CYAN}${BRANCH}${C_NC}"
    
    echo -e "\nDownloading..."
    local tmp_dir="/tmp/tox1c_updater"
    rm -rf "$tmp_dir"
    
    if git clone -b "$BRANCH" "https://github.com/${REPO}.git" "$tmp_dir" --quiet; then
        echo -e "${C_GREEN}✔ Download Complete.${C_NC}"
        echo -e "Installing..."
        chmod +x "$tmp_dir/install.sh"
        (cd "$tmp_dir" && bash install.sh)
        rm -rf "$tmp_dir"
        echo -e "${C_GREEN}✔ Update Complete. Restarting Dashboard...${C_NC}"
        sleep 2
        exec "$0"
    else
        echo -e "${C_RED}[!] Connection Failed.${C_NC}"
        pause
    fi
}

change_port() {
    draw_header
    echo -e "${C_YELLOW}[!] CHANGE SSH PORT (Stealth Mode)${C_NC}"
    local current=$(grep "^Port " /etc/ssh/sshd_config | head -n1 | awk '{print $2}' || echo "22")
    echo -e "Current Port: ${C_GREEN}$current${C_NC}"
    
    read -p "New Port (1024-65535 recommended): " new_p
    if [[ ! "$new_p" =~ ^[0-9]+$ ]] || [ "$new_p" -lt 1 ] || [ "$new_p" -gt 65535 ]; then
        echo -e "${C_RED}[!] Invalid Port.${C_NC}"; pause; return
    fi
    
    echo -e "Updating configuration..."
    if grep -q "^Port " /etc/ssh/sshd_config; then
        sed -i "s/^Port .*/Port $new_p/" /etc/ssh/sshd_config
    else
        echo "Port $new_p" >> /etc/ssh/sshd_config
    fi
    
    ufw allow "$new_p"/tcp >/dev/null
    ufw delete allow "$current"/tcp >/dev/null 2>&1
    ufw reload >/dev/null
    systemctl restart ssh
    
    echo -e "${C_GREEN}✔ Success. SSH is now on port $new_p.${C_NC}"
    pause
}

monitor() {
    draw_header
    echo -e "${C_YELLOW}[*] LIVE TRAFFIC MONITOR${C_NC} (Ctrl+C to Exit)"
    # Show active SSH connections and vnstat traffic
    watch -n 1 -c "echo 'ACTIVE CONNECTIONS:'; ps -eo user,cmd | grep 'sshd: ' | grep -v 'root' | grep -v 'grep' | awk '{print \$1}'; echo ''; vnstat -tr 2"
}

# --- MENUS ---

menu_users() {
    while true; do
        draw_header
        echo " 1) Create User"
        echo " 2) Remove User"
        echo " 3) Lock/Unlock User"
        echo " 0) Back"
        echo ""
        read -p " Select: " opt
        case $opt in
            1) create_user ;;
            2) remove_user ;;
            3) lock_unlock ;;
            0) return ;;
        esac
    done
}

menu_system() {
    while true; do
        draw_header
        echo " 1) Change SSH Port"
        echo " 2) Monitor Traffic"
        echo " 8) Update System"
        echo " 0) Back"
        echo ""
        read -p " Select: " opt
        case $opt in
            1) change_port ;;
            2) monitor ;;
            8) system_update ;;
            0) return ;;
        esac
    done
}

# --- ENTRY POINT ---
[[ $EUID -ne 0 ]] && { echo -e "${C_RED}[!] Root required.${C_NC}"; exit 1; }

while true; do
    draw_header
    echo " 1) User Management"
    echo " 2) System Settings"
    echo " 0) Exit"
    echo ""
    read -p " Select: " opt
    case $opt in
        1) menu_users ;;
        2) menu_system ;;
        0) exit ;;
    esac
done
