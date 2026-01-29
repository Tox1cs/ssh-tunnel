#!/bin/bash
# ==============================================================================
# MANAGER: TOX1C SSH-TUNNEL | DASHBOARD PRO (Grafana Edition)
# ==============================================================================

# CONFIG
readonly VPN_GROUP="tox1c-users"
readonly VERSION="3.0-PRO"
readonly REPO="Tox1cs/ssh-tunnel"
readonly BRANCH="dev"
readonly INTERFACE=$(ip route get 8.8.8.8 | grep -oP 'dev \K\S+')

# COLORS
C_RED='\033[0;31m'; C_GREEN='\033[0;32m'; C_YELLOW='\033[1;33m'; C_BLUE='\033[0;34m'
C_CYAN='\033[0;36m'; C_GRAY='\033[1;30m'; C_WHITE='\033[1;37m'; C_NC='\033[0m'
BG_BLUE='\033[44m'; BG_RESET='\033[49m'

# UTILS
pause() { echo ""; read -rsn1 -p "Press any key to return..."; echo ""; }
cursor_to() { tput cup $1 $2; }
draw_bar() {
    # $1=percent, $2=color
    local width=20
    local filled=$(( $1 * $width / 100 ))
    local empty=$(( $width - $filled ))
    printf "${2}["
    printf "%0.s|" $(seq 1 $filled)
    printf "${C_GRAY}%0.s." $(seq 1 $empty)
    printf "${2}]${C_NC}"
}

# --- ACTIONS ---
# (Keep create_user, remove_user, lock_unlock, change_port, update_system SAME AS BEFORE)
# I will only provide the NEW MONITOR function here to save space. 
# You must keep the other functions from the previous version!

# --- THE GRAFANA DASHBOARD ---
monitor() {
    # 1. Setup Canvas
    tput civis # Hide cursor
    trap 'tput cnorm; clear; return' EXIT SIGINT # Reset on exit
    
    # Init Traffic History
    declare -a history_rx=(0 0 0 0 0 0 0 0 0 0)
    declare -a history_tx=(0 0 0 0 0 0 0 0 0 0)
    
    while true; do
        # -- 1. GATHER DATA --
        # CPU Load
        local cpu_load=$(top -bn1 | grep "Cpu(s)" | awk '{print $2 + $4}' | awk -F. '{print $1}')
        # RAM Load
        local mem_used=$(free -m | grep Mem | awk '{print $3}')
        local mem_total=$(free -m | grep Mem | awk '{print $2}')
        local mem_perc=$(( mem_used * 100 / mem_total ))
        
        # Network Speed
        local rx1=$(cat /sys/class/net/$INTERFACE/statistics/rx_bytes)
        local tx1=$(cat /sys/class/net/$INTERFACE/statistics/tx_bytes)
        sleep 1
        local rx2=$(cat /sys/class/net/$INTERFACE/statistics/rx_bytes)
        local tx2=$(cat /sys/class/net/$INTERFACE/statistics/tx_bytes)
        
        # Calculate Speed (Bytes/sec)
        local rx_speed=$(( (rx2 - rx1) ))
        local tx_speed=$(( (tx2 - tx1) ))
        
        # Convert to KB/s
        local rx_kb=$(( rx_speed / 1024 ))
        local tx_kb=$(( tx_speed / 1024 ))
        
        # Service Status
        local ssh_status="${C_RED}OFFLINE${C_NC}"
        systemctl is-active --quiet ssh && ssh_status="${C_GREEN}ACTIVE ${C_NC}"
        
        local gw_status="${C_RED}FAILED ${C_NC}"
        if systemctl is-active --quiet tox1c-tunnel.service; then
            gw_status="${C_GREEN}ONLINE ${C_NC}"
        else
            # Try to diagnose
            if [ ! -f /opt/tox1c-sshtunnel/bin/tox1c-udpgw ]; then gw_status="${C_RED}MISSING${C_NC}"; fi
        fi

        # Active Users
        local active_users=$(ps -eo user,cmd | grep 'sshd: ' | grep -v 'root' | grep -v 'grep' | awk '{print $1}' | sort | uniq -c)
        local user_count=$(echo "$active_users" | wc -l)
        
        # -- 2. DRAW UI --
        clear
        echo -e "${BG_BLUE}${C_WHITE}  TOX1C MONITOR PRO v3.0  ${BG_RESET}${C_CYAN}  Ctrl+C to Exit  ${C_NC}"
        echo -e "${C_GRAY}──────────────────────────────────────────────────${C_NC}"
        
        # SECTION: HEALTH
        printf " ${C_YELLOW}SYSTEM HEALTH:${C_NC}\n"
        printf " CPU: %-3s%% %s   SSH: %b\n" "$cpu_load" "$(draw_bar $cpu_load $C_GREEN)" "$ssh_status"
        printf " RAM: %-3s%% %s   GW:  %b\n" "$mem_perc" "$(draw_bar $mem_perc $C_BLUE)" "$gw_status"
        
        echo -e "${C_GRAY}──────────────────────────────────────────────────${C_NC}"
        
        # SECTION: NETWORK
        printf " ${C_YELLOW}NETWORK TRAFFIC ($INTERFACE):${C_NC}\n"
        printf " ${C_GREEN}⬇ DOWNLOAD:${C_NC} %5s KB/s   " "$rx_kb"
        printf " ${C_BLUE}⬆ UPLOAD:${C_NC}   %5s KB/s\n" "$tx_kb"
        
        # Visual Graph (Simplified Sparkline)
        # We normalize speed to 0-10 scale for drawing bars
        local bar_len=$(( rx_kb / 10 ))
        [[ $bar_len -gt 40 ]] && bar_len=40
        printf " ${C_GREEN}RX:${C_NC} "
        printf "%0.s█" $(seq 1 $bar_len)
        printf "\n"
        
        echo -e "${C_GRAY}──────────────────────────────────────────────────${C_NC}"
        
        # SECTION: USERS
        printf " ${C_YELLOW}ACTIVE USERS ($user_count):${C_NC}\n"
        printf " %-15s | %-10s\n" "USERNAME" "STATUS"
        echo -e " ${C_GRAY}---------------------------${C_NC}"
        
        if [[ -z "$active_users" ]]; then
             echo -e " ${C_GRAY}(No users connected)${C_NC}"
        else
             while read -r count user; do
                 [[ -z "$user" ]] && continue
                 printf " ${C_WHITE}%-15s${C_NC} | ${C_GREEN}Connected${C_NC}\n" "$user"
             done <<< "$active_users"
        fi
        
        echo -e "${C_GRAY}──────────────────────────────────────────────────${C_NC}"
    done
}

# --- REST OF THE SCRIPT (Keep your Headers, Create User, Menus, etc.) ---
# COPY PASTE THE REST OF THE PREVIOUS SCRIPT HERE
# BUT REPLACE THE OLD 'monitor' FUNCTION WITH THIS NEW ONE
