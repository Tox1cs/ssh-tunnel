#!/bin/bash

set -u

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly INSTALL_DIR="${INSTALL_DIR:-/opt/tox1c-sshtunnel}"
readonly INTERFACE=$(ip route get 8.8.8.8 2>/dev/null | grep -oP 'dev \K\S+' || echo "eth0")

source "$SCRIPT_DIR/lib/colors.sh"
source "$SCRIPT_DIR/lib/utils.sh"
source "$SCRIPT_DIR/lib/metrics.sh"
source "$SCRIPT_DIR/lib/users.sh"
source "$SCRIPT_DIR/lib/system.sh"
source "$SCRIPT_DIR/ui/render.sh"

trap 'tput cnorm 2>/dev/null; exit 0' EXIT SIGINT SIGTERM

monitor_dashboard() {
    draw_header
    tput civis
    
    while true; do
        local cpu=$(get_cpu_usage)
        local mem=$(get_memory_usage)
        local mem_mb=$(get_memory_mb)
        local speeds=$(get_network_speed "$INTERFACE")
        local rx_speed=$(echo $speeds | awk '{print $1}')
        local tx_speed=$(echo $speeds | awk '{print $2}')
        local ssh_status=$(get_service_status ssh)
        local gw_status=$(get_service_status tox1c-tunnel.service)
        local user_count=$(get_active_users)
        local uptime=$(get_uptime)
        local load=$(get_load_average)
        
        clear
        
        echo -e "${BG_BLUE}${C_WHITE}  ⚡ TOX1C LIVE MONITOR  ${BG_RESET}${C_CYAN}  Press Ctrl+C to Exit  ${C_NC}"
        draw_separator
        
        echo ""
        draw_section_title "SYSTEM RESOURCES"
        draw_two_column "CPU Usage" "$(draw_progress_bar $cpu $C_GREEN)" "SSH Service" "$(draw_status_badge $ssh_status)"
        draw_two_column "Memory" "$(draw_progress_bar $mem $C_BLUE)" "UDP Gateway" "$(draw_status_badge $gw_status)"
        echo -e " ${C_CYAN}Memory Details${C_NC}     $mem_mb MB"
        echo -e " ${C_CYAN}Load Average${C_NC}      $load"
        echo -e " ${C_CYAN}System Uptime${C_NC}     $uptime"
        
        echo ""
        draw_section_title "NETWORK PERFORMANCE ($INTERFACE)"
        echo -e " ${C_GREEN}⬇ Download${C_NC}        $(printf '%6d' $rx_speed) KB/s"
        echo -e " ${C_BLUE}⬆ Upload${C_NC}          $(printf '%6d' $tx_speed) KB/s"
        
        local activity_len=$(( (rx_speed + tx_speed) / 100 ))
        [ $activity_len -gt 40 ] && activity_len=40
        printf " ${C_PURPLE}Activity${C_NC}          "
        [ $activity_len -gt 0 ] && printf "%0.s█" $(seq 1 $activity_len)
        echo ""
        
        echo ""
        draw_section_title "CONNECTED USERS ($user_count)"
        
        if [ $user_count -eq 0 ]; then
            echo -e " ${C_GRAY}No active sessions${C_NC}"
        else
            get_active_users_list | while read -r user; do
                echo -e " ${C_GREEN}●${C_NC} $user"
            done
        fi
        
        echo ""
        draw_separator
        echo -e "${C_GRAY}Last updated: $(date '+%H:%M:%S')${C_NC}"
        
        sleep 2
    done
}

menu_users() {
    while true; do
        draw_header
        draw_section_title "USER MANAGEMENT"
        echo ""
        draw_menu_item "1" "Create VPN User"
        draw_menu_item "2" "Delete VPN User"
        draw_menu_item "3" "List VPN Users"
        draw_menu_item "4" "Reset User Password"
        draw_menu_item "0" "Back to Main Menu"
        echo ""
        
        read -p " Select option: " choice
        
        case $choice in
            1) create_vpn_user ;;
            2) delete_vpn_user ;;
            3) list_vpn_users ;;
            4) reset_user_password ;;
            0) return ;;
            *) error "Invalid option" ;;
        esac
    done
}

menu_system() {
    while true; do
        draw_header
        draw_section_title "SYSTEM SETTINGS"
        echo ""
        draw_menu_item "1" "Change SSH Port"
        draw_menu_item "2" "Enable SSH Key Authentication"
        draw_menu_item "3" "Optimize Network Performance"
        draw_menu_item "4" "View System Information"
        draw_menu_item "5" "View System Logs"
        draw_menu_item "0" "Back to Main Menu"
        echo ""
        
        read -p " Select option: " choice
        
        case $choice in
            1) change_ssh_port ;;
            2) enable_key_auth ;;
            3) optimize_network ;;
            4) view_system_info ;;
            5) view_logs ;;
            0) return ;;
            *) error "Invalid option" ;;
        esac
    done
}

menu_main() {
    while true; do
        draw_header
        echo ""
        draw_menu_item "1" "User Management"
        draw_menu_item "2" "Live Monitor Dashboard"
        draw_menu_item "3" "System Settings"
        draw_menu_item "0" "Exit"
        echo ""
        
        read -p " Select option: " choice
        
        case $choice in
            1) menu_users ;;
            2) monitor_dashboard ;;
            3) menu_system ;;
            0) 
                clear
                echo -e "${C_GREEN}Goodbye!${C_NC}"
                exit 0
                ;;
            *) error "Invalid option" ;;
        esac
    done
}

require_root
menu_main
