#!/bin/bash
# ==============================================================================
# MANAGER: TOX1C SSH-TUNNEL | MONITOR PRO
# ==============================================================================

# CONFIG
readonly VPN_GROUP="tox1c-users"
readonly VERSION="3.1-GRAFANA"
readonly REPO="Tox1cs/ssh-tunnel"
readonly BRANCH="dev"
# Detect Network Interface
INTERFACE=$(ip route get 8.8.8.8 | grep -oP 'dev \K\S+')

# COLORS
C_RED='\033[0;31m'; C_GREEN='\033[0;32m'; C_YELLOW='\033[1;33m'; C_BLUE='\033[0;34m'
C_CYAN='\033[0;36m'; C_GRAY='\033[1;30m'; C_WHITE='\033[1;37m'; C_NC='\033[0m'
BG_BLUE='\033[44m'; BG_RESET='\033[49m'

# --- UTILS ---
pause() { echo ""; read -rsn1 -p "Press any key to return..."; echo ""; }

draw_bar() {
    # Usage: draw_bar <percentage> <color_code>
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

validate_input() {
    if [[ ! "$1" =~ ^[a-zA-Z0-9_-]+$ ]]; then
        echo -e "${C_RED}[!] Error: Invalid characters.${C_NC}"; pause; return 1
    fi
    return 0
}

# --- HEADER (Standard) ---
draw_header() {
    clear
    local title="TOX1C SSH-TUNNEL PRO"
    echo -e "${C_CYAN}╔══════════════════════════════════════════════════════════════╗${C_NC}"
    printf "${C_CYAN}║${C_NC}%*s${C_CYAN}║${C_NC}\n" 60 "$(printf "%*s%s%*s" 20 "" "$title" 20 "")"
    echo -e "${C_CYAN}╠══════════════════════════════════════════════════════════════╣${C_NC}"
    printf "${C_CYAN}║${C_NC}  GitHub: github.com/${REPO}                  ${C_GRAY}v${VERSION}   ${C_NC}${C_CYAN}║${C_NC}\n"
    echo -e "${C_CYAN}╚══════════════════════════════════════════════════════════════╝${C_NC}"
}

# --- MONITOR (THE GRAFANA UPGRADE) ---
monitor() {
    # Hide cursor
    tput civis
    trap 'tput cnorm; clear; return' EXIT SIGINT

    while true; do
        # 1. Gather Metrics
        # CPU
        local cpu_load=$(grep 'cpu ' /proc/stat | awk '{usage=($2+$4)*100/($2+$4+$5)} END {print usage}' | cut -d. -f1)
        # RAM
        local mem_used=$(free -m | grep Mem | awk '{print $3}')
        local mem_total=$(free -m | grep Mem | awk '{print $2}')
        local mem_perc=$(( mem_used * 100 / mem_total ))
        
        # Traffic (Snapshot 1)
        local rx1=$(cat /sys/class/net/$INTERFACE/statistics/rx_bytes)
        local tx1=$(cat /sys/class/net/$INTERFACE/statistics/tx_bytes)
        sleep 1
        # Traffic (Snapshot 2)
        local rx2=$(cat /sys/class/net/$INTERFACE/statistics/rx_bytes)
        local tx2=$(cat /sys/class/net/$INTERFACE/statistics/tx_bytes)
        
        # Calc
        local rx_speed=$(( (rx2 - rx1) / 1024 )) # KB/s
        local tx_speed=$(( (tx2 - tx1) / 1024 )) # KB/s
        
        # Service Checks
        local ssh_s="${C_RED}OFFLINE${C_NC}"
        systemctl is-active --quiet ssh && ssh_s="${C_GREEN}ACTIVE ${C_NC}"
        local gw_s="${C_RED}FAILED ${C_NC}"
        systemctl is-active --quiet tox1c-tunnel.service && gw_s="${C_GREEN}ONLINE ${C_NC}"

        # Users
        local active_users=$(ps -eo user,cmd | grep 'sshd: ' | grep -v 'root' | grep -v 'grep' | awk '{print $1}' | sort | uniq -c)
        local user_count=$(echo "$active_users" | wc -l)
        if [[ -z "$active_users" ]]; then user_count=0; fi

        # 2. Draw Dashboard
        clear
        echo -e "${BG_BLUE}${C_WHITE}  TOX1C LIVE MONITOR  ${BG_RESET}${C_CYAN}  (Ctrl+C to Exit)  ${C_NC}"
        echo -e "${C_GRAY}──────────────────────────────────────────────────────────${C_NC}"
        
        # ROW 1: HEALTH
        printf " ${C_YELLOW}SYSTEM RESOURCES:${C_NC}\n"
        printf " CPU: %3s%% %s   SSH Service: %b\n" "$cpu_load" "$(draw_bar $cpu_load $C_GREEN)" "$ssh_s"
        printf " RAM: %3s%% %s   UDP Gateway: %b\n" "$mem_perc" "$(draw_bar $mem_perc $C_BLUE)" "$gw_s"
        echo -e "${C_GRAY}──────────────────────────────────────────────────────────${C_NC}"
        
        # ROW 2: NETWORK
        printf " ${C_YELLOW}LIVE TRAFFIC ($INTERFACE):${C_NC}\n"
        printf " ${C_GREEN}⬇ DOWNLOAD:${C_NC} %-6s KB/s   " "$rx_speed"
        printf " ${C_BLUE}⬆ UPLOAD:${C_NC}   %-6s KB/s\n" "$tx_speed"
        
        # Visual Sparkline (Simulated)
        local bar_len=$(( rx_speed / 50 )) # 1 block per 50KB
        [[ $bar_len -gt 30 ]] && bar_len=30
        printf " ${C_GREEN}RX Graph:${C_NC} "
        if [[ $bar_len -gt 0 ]]; then printf "%0.s█" $(seq 1 $bar_len); fi
        printf "\n"
        echo -e "${C_GRAY}──────────────────────────────────────────────────────────${C_NC}"
        
        # ROW 3: USERS
        printf " ${C_YELLOW}CONNECTED USERS ($user_count):${C_NC}\n"
        if [[ $user_count -eq 0 ]]; then
             echo -e " ${C_GRAY}(No users connected)${C_NC}"
        else
             echo "$active_users" | while read -r count user; do
                 [[ -z "$user" ]] && continue
                 printf "  • ${C_WHITE}%-15s${C_NC} ${C_GREEN}● Connected${C_NC}\n" "$user"
             done
        fi
        echo -e "${C_GRAY}──────────────────────────────────────────────────────────${C_NC}"
    done
}

# --- BASIC FUNCTIONS (Keeping your existing logic) ---
create_user() {
    draw_header
    echo -e "${C_GREEN}[+] CREATE USER${C_NC}"
    read -p "Username: " u
    validate_input "$u" || return
    if id "$u" &>/dev/null; then echo -e "${C_RED}[!] Exists.${C_NC}"; pause; return; fi
    read -p "Password (Random): " p
    [[ -z "$p" ]] && p=$(openssl rand -base64 12)
    read -p "Expiry Days (30): " days
    [[ -z "$days" ]] && days=30
    useradd -m -s /usr/sbin/nologin -G "$VPN_GROUP" "$u"
    echo "$u:$p" | chpasswd
    chage -E "$(date -d "+$days days" +%Y-%m-%d)" "$u"
    echo -e "${C_GREEN}✔ Created: $u / $p${C_NC}"; pause
}

remove_user() {
    draw_header
    echo -e "${C_RED}[-] REMOVE USER${C_NC}"
    grep "$VPN_GROUP" /etc/group | cut -d: -f4 | tr ',' '\n' | sed '/^$/d' | sed 's/^/ - /'
    echo ""
    read -p "Username: " u
    validate_input "$u" || return
    if id -nG "$u" 2>/dev/null | grep -qw "$VPN_GROUP"; then
        pkill -u "$u"; userdel -r "$u"; echo -e "${C_GREEN}✔ Deleted.${C_NC}"
    else echo -e "${C_RED}[!] Not found.${C_NC}"; fi
    pause
}

system_update() {
    draw_header
    echo -e "${C_YELLOW}[*] SYSTEM UPDATE (Dev)${C_NC}"
    rm -rf /tmp/tox1c_updater
    if git clone -b "$BRANCH" "https://github.com/${REPO}.git" /tmp/tox1c_updater; then
        bash /tmp/tox1c_updater/install.sh
        sleep 2; exec "$0"
    else echo -e "${C_RED}Update Failed.${C_NC}"; pause; fi
}

change_port() {
    draw_header
    read -p "New Port: " p
    [[ ! "$p" =~ ^[0-9]+$ ]] && return
    sed -i "s/^Port .*/Port $p/" /etc/ssh/sshd_config || echo "Port $p" >> /etc/ssh/sshd_config
    ufw allow "$p"/tcp; systemctl restart ssh
    echo -e "${C_GREEN}✔ Done.${C_NC}"; pause
}

# --- MENUS ---
menu_main() {
    while true; do
        draw_header
        echo " 1) User Management"
        echo " 2) Live Monitor (Grafana)"
        echo " 3) System Settings"
        echo " 0) Exit"
        read -p " Select: " o
        case $o in
            1) menu_users ;;
            2) monitor ;;
            3) menu_sys ;;
            0) exit ;;
        esac
    done
}

menu_users() {
    while true; do
        draw_header
        echo " 1) Create User"
        echo " 2) Remove User"
        echo " 0) Back"
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
        read -p " Select: " o
        case $o in 1) change_port ;; 8) system_update ;; 0) return ;; esac
    done
}

# --- START ---
[[ $EUID -ne 0 ]] && { echo "Root required."; exit 1; }
menu_main
