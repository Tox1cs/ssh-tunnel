#!/bin/bash

source "$(dirname "${BASH_SOURCE[0]}")/../lib/colors.sh"

draw_box() {
    local width=${1:-60}
    local title="${2:-}"
    local inner_width=$((width - 2))
    
    echo -e "${C_CYAN}┌$(printf '─%.0s' $(seq 1 $inner_width))┐${C_NC}"
    
    if [ -n "$title" ]; then
        local padding=$(( (inner_width - ${#title}) / 2 ))
        printf "${C_CYAN}│${C_NC}"
        printf "%*s${C_WHITE}${BOLD}%s${C_NC}%*s" $padding "" "$title" $padding ""
        [ $(( (inner_width - ${#title}) % 2 )) -ne 0 ] && printf " "
        echo -e "${C_CYAN}│${C_NC}"
    fi
    
    echo -e "${C_CYAN}└$(printf '─%.0s' $(seq 1 $inner_width))┘${C_NC}"
}

draw_header() {
    clear
    draw_box 62 "TOX1C SSH-TUNNEL v3.1"
    echo ""
}

draw_progress_bar() {
    local percent=$1
    local color=${2:-$C_GREEN}
    local width=20
    local filled=$(( percent * width / 100 ))
    local empty=$(( width - filled ))
    
    printf "${color}["
    printf "%0.s█" $(seq 1 $filled)
    printf "${C_GRAY}%0.s░" $(seq 1 $empty)
    printf "${color}]${C_NC} %3d%%" "$percent"
}

draw_separator() {
    echo -e "${C_GRAY}$(printf '─%.0s' $(seq 1 60))${C_NC}"
}

draw_status_badge() {
    local status=$1
    local color=$2
    
    case "$status" in
        "ACTIVE"|"ONLINE"|"OK")
            echo -e "${C_GREEN}● $status${C_NC}"
            ;;
        "OFFLINE"|"FAILED"|"ERROR")
            echo -e "${C_RED}● $status${C_NC}"
            ;;
        *)
            echo -e "${C_YELLOW}● $status${C_NC}"
            ;;
    esac
}

draw_menu_item() {
    local num=$1
    local text=$2
    echo -e " ${C_CYAN}$num)${C_NC} $text"
}

draw_section_title() {
    local title=$1
    echo -e "${C_YELLOW}${BOLD}▶ $title${C_NC}"
}

draw_info_row() {
    local label=$1
    local value=$2
    printf " ${C_CYAN}%-20s${C_NC} %s\n" "$label:" "$value"
}

draw_two_column() {
    local left_label=$1
    local left_value=$2
    local right_label=$3
    local right_value=$4
    
    printf " ${C_CYAN}%-18s${C_NC} %-20s ${C_CYAN}%-18s${C_NC} %s\n" \
        "$left_label:" "$left_value" "$right_label:" "$right_value"
}

draw_spinner() {
    local pid=$1
    local spin=( '⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏' )
    local i=0
    
    while kill -0 $pid 2>/dev/null; do
        printf "\r${C_CYAN}${spin[$i]}${C_NC} Processing..."
        i=$(( (i+1) % 10 ))
        sleep 0.1
    done
    printf "\r${C_GREEN}✔${C_NC} Complete!   \n"
}

clear_line() {
    printf "\r%60s\r" ""
}
