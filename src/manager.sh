#!/bin/bash
# ==============================================================================
# MANAGER: TOX1C SSH-TUNNEL | PRO EDITION (FINAL POLISH)
# ==============================================================================

# --- CONFIGURATION ---
readonly VPN_GROUP="tox1c-users"
readonly REPO="Tox1cs/ssh-tunnel"
readonly BRANCH="main"
# Auto-detect primary interface
readonly INTERFACE=$(ip route get 8.8.8.8 | grep -oP 'dev \K\S+')

# --- COLORS ---
readonly C_RED='\033[0;31m'
readonly C_GREEN='\033[0;32m'
readonly C_YELLOW='\033[1;33m'
readonly C_BLUE='\033[0;34m'
readonly C_CYAN='\033[0;36m'
readonly C_PURPLE='\033[0;35m'
readonly C_GRAY='\033[1;30m'
readonly C_WHITE='\033[1;37m'
readonly C_NC='\033[0m'
readonly BG_BLUE='\033[44m'
readonly BG_RESET='\033[49m'

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

draw_bar() {
    # Usage: draw_bar <percent> <color_code>
    local percent=$1
    local color=$2
    local width=15
    local filled=$(( percent * width / 100 ))
    local empty=$(( width - filled ))
    printf "${color}["
    printf "%0.s|" $(seq 1 $filled)
    printf "${C_GRAY}%0.s." $(seq 1 $empty)
    printf "${color}]${C_NC}"
}

center_text() {
    # Usage: center_text "Text" "Color" Width
    local text="$1"
    local color="$2"
    local width="${3:-58}" # Default inner width
    local padding=$(( (width - ${#text}) / 2 ))
    printf "${color}%*s%s%*s${C_NC}" $padding "" "$text" $padding ""
    # Handle odd lengths
    if [[ $(( (width - ${#text}) % 2 )) -ne 0 ]]; then printf " "; fi
}

# --- UI COMPONENTS ---

draw_header() {
    clear
    # Box Width: 60 chars (Border to Border)
    # Inner Width: 58 chars
    
    echo -e "${C_CYAN}┌──────────────────────────────────────────────────────────┐${C_NC}"
    
    # Title Line
    printf "${C_CYAN}│${C_NC}"
    center_text "TOX1C SSH-TUNNEL" "${C_WHITE}" 58
    printf "${C_CYAN}│${C_NC}\n"
    
    # Link Line
    printf "${C_CYAN}│${C_NC}"
    # We use OSC 8 hyperlink if terminal supports it, otherwise just text
    # But for safety/compatibility, we just print the clean URL
    center_text "github.com/${REPO}" "${C_BLUE}" 58
    printf "${C_CYAN}│${C_NC}\n"
    
    echo -e "${C_CYAN}└──────────────────────────────────────────────────────────┘${C_NC}"
}

# --- MONITORING ENGINE ---

monitor() {
    # Hide cursor
    tput civis
    trap 'tput cnorm; clear; return' EXIT SIGINT

    while true; do
        # 1. Gather System Metrics
        # CPU Usage (Greps top or proc)
        local cpu_load=$(grep 'cpu ' /proc/stat | awk '{usage=($2+$4)*100/($2+$4+$5)} END {print usage}' | cut -d. -f1)
        
        # Memory Usage
        local mem_used=$(free -m | grep Mem | awk '{print $3}')
        local mem_total=$(free -m | grep Mem | awk '{print $2}')
        local mem_perc=0
        if [[ $mem_total -gt 0 ]]; then
            mem_perc=$(( mem_used * 100 / mem_total ))
        fi
        
        # 2. Network Metrics (Snapshot 1)
        # REAL DATA from Kernel
        local rx1=$(cat /sys/class/net/$INTERFACE/statistics/rx_bytes)
        local tx1=$(cat /sys/class/net/$INTERFACE/statistics/tx_bytes)
        sleep 1
        # Network Metrics (Snapshot 2)
        local rx2=$(cat /sys/class/net/$INTERFACE/statistics/rx_bytes)
        local tx2=$(cat /sys/class/net/$INTERFACE/statistics/tx_bytes)
        
        # Calculate Speed (KB/s) - Bash integer math is fine here
        local rx_speed=$(( (rx2 - rx1) / 1024 ))
        local tx_speed=$(( (tx2 - tx1) / 1024 ))
        
        # 3. Service Status
        local ssh_s="${C_RED}OFFLINE${C_NC}"
        systemctl is-active --quiet ssh && ssh_s="${C_GREEN}ACTIVE ${C_NC}"
        
        local gw_s="${C_RED}FAILED ${C_NC}"
        if systemctl is-active --quiet tox1c-tunnel.service; then
            gw_s="${C_GREEN}ONLINE ${C_NC}"
        fi

        # 4. User Stats
        local active_users=$(ps -eo user,cmd | grep 'sshd: ' | grep -v 'root' | grep -v 'grep' | awk '{print $1}' | sort | uniq -c)
        local user_count=$(echo "$active_users" | wc -l)
        if [[ -z "$active_users" ]]; then user_count=0; fi

        # 5. Render UI
        clear
        echo -e "${BG_BLUE}${C_WHITE}  TOX1C LIVE MONITOR  ${BG_RESET}${C_CYAN}  (Ctrl+C to Exit)  ${C_NC}"
        echo -e "${C_GRAY}──────────────────────────────────────────────────────────${C_NC}"
        
        # SYSTEM ROW
        printf " ${C_YELLOW}RESOURCES:${C_NC}\n"
        printf " CPU: %3s%% %s   SSH Service: %b\n" "$cpu_load" "$(draw_bar $cpu_load $C_GREEN)" "$ssh_s"
        printf " RAM: %3s%% %s   UDP Gateway: %b\n" "$mem_perc" "$(draw_bar $mem_perc $C_BLUE)" "$gw_s"
        echo -e "${C_GRAY}──────────────────────────────────────────────────────────${C_NC}"
        
        # NETWORK ROW
        printf " ${C_YELLOW}NETWORK ($INTERFACE):${C_NC}\n"
        printf " ${C_GREEN}⬇ DOWNLOAD:${C_NC} %-6s KB/s   " "$rx_speed"
        printf " ${C_BLUE}⬆ UPLOAD:${C_NC}   %-6s KB/s\n" "$tx_speed"
        
        # Visual Activity Bar (Sparkline)
        # Scaled: 1 block = 50KB/s roughly, max 30 blocks
        local bar_len=$(( rx_speed / 50 )) 
        [[ $bar_len -gt 30 ]] && bar_len=30
        printf " ${C_GREEN}Activity:${C_NC}   "
        if [[ $bar_len -gt 0 ]]; then printf "%0.s█" $(seq 1 $bar_len); fi
        printf "\n"
        echo -e "${C_GRAY}──────────────────────────────────────────────────────────${C_NC}"
        
        # USER ROW
        printf " ${C_YELLOW}CONNECTED USERS ($user_count):${C_NC}\n"
        if [[ $user_count -eq 0 ]]; then
             echo -e " ${C_GRAY}(No active sessions)${C_NC}"
        else
             echo "$active_users" | while read -r count user; do
                 [[ -z "$user" ]] && continue
                 printf "  • ${C_WHITE}%-15s${C_NC} ${C_GREEN}● Connected${C_NC}\n" "$user"
             done
        fi
        echo -e "${C_GRAY}──────────────────────────────────────────────────────────${C_NC}"
    done
}

# --- CORE FUNCTIONS ---

create_user() {
    draw_header
    echo -e "${C_GREEN}[+] CREATE USER${C_NC}"
    read -p "Username: " u
    validate_input "$u" || return
    
    if id "$u" &>/dev/null; then echo -e "${C_RED}[!] User exists.${C_NC}"; pause; return; fi

    read -p "Password (Leave empty for random): " p
    [[ -z "$p" ]] && p=$(openssl rand -base64 12)
    
    read -p "Expiry Days (Default 30): " days
    [[ -z "$days" ]] && days=30
    
    useradd -m -s /usr/sbin/nologin -G "$VPN_GROUP" "$u"
    echo "$u:$p" | chpasswd
    chage -E "$(date -d "+$days days" +%Y-%m-%d)" "$u"
    
    echo -e "\n${C_GREEN}✔ User Created.${C_NC}"
    echo -e "User: ${C_YELLOW}$u${C_NC}"
    echo -e "Pass: ${C_YELLOW}$p${C_NC}"
    pause
}

remove_user() {
    draw_header
    echo -e "${C_RED}[-] DELETE USER${C_NC}"
    grep "$VPN_GROUP" /etc/group | cut -d: -f4 | tr ',' '\n' | sed '/^$/d' | sed 's/^/ - /'
    echo ""
    read -p "Username: " u
    validate_input "$u" || return
    
    if id -nG "$u" 2>/dev/null | grep -qw "$VPN_GROUP"; then
        pkill -u "$u"
        userdel -r "$u"
        echo -e "${C_GREEN}✔ Deleted.${C_NC}"
    else
        echo -e "${C_RED}[!] Not found.${C_NC}"
    fi
    pause
}

system_update() {
    draw_header
    echo -e "${C_YELLOW}[*] SYSTEM UPDATE${C_NC}"
    echo -e "Updating from branch: ${C_CYAN}${BRANCH}${C_NC}"
    
    rm -rf /tmp/tox1c_updater
    if git clone -b "$BRANCH" "https://github.com/${REPO}.git" /tmp/tox1c_updater --quiet; then
        echo -e "${C_GREEN}✔ Downloaded.${C_NC} Installing..."
        bash /tmp/tox1c_updater/install.sh
        sleep 2
        exec "$0"
    else
        echo -e "${C_RED}[!] Update Failed. Check internet.${C_NC}"
        pause
    fi
}

change_port() {
    draw_header
    echo -e "${C_YELLOW}[!] CHANGE SSH PORT${C_NC}"
    read -p "New Port: " p
    if [[ ! "$p" =~ ^[0-9]+$ ]] || [ "$p" -lt 1 ] || [ "$p" -gt 65535 ]; then
         echo -e "${C_RED}Invalid.${C_NC}"; pause; return
    fi
    
    sed -i "s/^Port .*/Port $p/" /etc/ssh/sshd_config || echo "Port $p" >> /etc/ssh/sshd_config
    ufw allow "$p"/tcp
    systemctl restart ssh
    echo -e "${C_GREEN}✔ SSH Port changed to $p.${C_NC}"
    pause
}

# --- MENUS ---

menu_users() {
    while true; do
        draw_header
        echo " 1) Create User"
        echo " 2) Remove User"
        echo " 0) Back"
        echo ""
        read -p " Select: " o
        case $o in 1) create_user ;; 2) remove_user ;; 0) return ;; esac
    done
}

menu_sys() {
    while true; do
        draw_header
        echo " 1) Change SSH Port"
        echo " 8) Update System"
        echo " 0) Back"
        echo ""
        read -p " Select: " o
        case $o in 1) change_port ;; 8) system_update ;; 0) return ;; esac
    done
}

menu_main() {
    while true; do
        draw_header
        echo " 1) User Management"
        echo " 2) Live Monitor"
        echo " 3) System Settings"
        echo " 0) Exit"
        echo ""
        read -p " Select: " o
        case $o in 1) menu_users ;; 2) monitor ;; 3) menu_sys ;; 0) exit ;; esac
    done
}

# --- ENTRY ---
[[ $EUID -ne 0 ]] && { echo "Root required."; exit 1; }
menu_main
