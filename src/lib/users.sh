#!/bin/bash

source "$(dirname "${BASH_SOURCE[0]}")/../lib/colors.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../lib/utils.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../ui/render.sh"

readonly VPN_GROUP="tox1c-users"

create_vpn_user() {
    draw_header
    draw_section_title "CREATE VPN USER"
    echo ""
    
    read -p " Username: " username
    
    if ! validate_username "$username"; then
        error "Invalid username (3-32 chars, alphanumeric, dash, underscore)"
        pause_menu
        return 1
    fi
    
    if id "$username" &>/dev/null; then
        error "User already exists"
        pause_menu
        return 1
    fi
    
    read -sp " Password (or press Enter for random): " password
    echo ""
    
    if [ -z "$password" ]; then
        password=$(openssl rand -base64 16 | tr -d '=+/' | cut -c1-16)
    fi
    
    read -p " Expiry days (default 30): " expiry_days
    expiry_days=${expiry_days:-30}
    
    if ! validate_days "$expiry_days"; then
        error "Invalid expiry days"
        pause_menu
        return 1
    fi
    
    if ! useradd -m -s /usr/sbin/nologin -G "$VPN_GROUP" "$username" 2>/dev/null; then
        error "Failed to create user"
        pause_menu
        return 1
    fi
    
    echo "$username:$password" | chpasswd
    chage -E "$(date -d "+$expiry_days days" +%Y-%m-%d)" "$username"
    
    echo ""
    success "User created successfully"
    echo -e " ${C_WHITE}Username:${C_NC} $username"
    echo -e " ${C_WHITE}Password:${C_NC} $password"
    echo -e " ${C_WHITE}Expires:${C_NC} $(date -d "+$expiry_days days" +%Y-%m-%d)"
    pause_menu
}

delete_vpn_user() {
    draw_header
    draw_section_title "DELETE VPN USER"
    echo ""
    
    local users=$(getent group "$VPN_GROUP" | cut -d: -f4 | tr ',' '\n' | sed '/^$/d')
    
    if [ -z "$users" ]; then
        warn "No VPN users found"
        pause_menu
        return
    fi
    
    echo " Available users:"
    echo "$users" | sed 's/^/  - /'
    echo ""
    
    read -p " Username to delete: " username
    
    if ! validate_username "$username"; then
        error "Invalid username"
        pause_menu
        return 1
    fi
    
    if ! id -nG "$username" 2>/dev/null | grep -qw "$VPN_GROUP"; then
        error "User not found in VPN group"
        pause_menu
        return 1
    fi
    
    read -p " Confirm deletion of '$username' (yes/no): " confirm
    if [ "$confirm" != "yes" ]; then
        warn "Cancelled"
        pause_menu
        return
    fi
    
    pkill -u "$username" 2>/dev/null || true
    userdel -r "$username" 2>/dev/null
    
    success "User deleted"
    pause_menu
}

list_vpn_users() {
    draw_header
    draw_section_title "VPN USERS"
    echo ""
    
    local users=$(getent group "$VPN_GROUP" | cut -d: -f4 | tr ',' '\n' | sed '/^$/d')
    
    if [ -z "$users" ]; then
        echo -e " ${C_GRAY}No VPN users configured${C_NC}"
        pause_menu
        return
    fi
    
    echo " ${C_CYAN}Username${C_NC}          ${C_CYAN}Expires${C_NC}          ${C_CYAN}Status${C_NC}"
    draw_separator
    
    while IFS= read -r user; do
        local expiry=$(chage -l "$user" 2>/dev/null | grep "Account expires" | cut -d: -f2 | xargs)
        local sessions=$(ps -eo user,cmd 2>/dev/null | grep -c "sshd: $user")
        local status=$([ $sessions -gt 0 ] && echo -e "${C_GREEN}Connected${C_NC}" || echo -e "${C_GRAY}Idle${C_NC}")
        
        printf " %-15s %-20s %b\n" "$user" "$expiry" "$status"
    done <<< "$users"
    
    pause_menu
}

reset_user_password() {
    draw_header
    draw_section_title "RESET USER PASSWORD"
    echo ""
    
    read -p " Username: " username
    
    if ! validate_username "$username"; then
        error "Invalid username"
        pause_menu
        return 1
    fi
    
    if ! id "$username" &>/dev/null; then
        error "User not found"
        pause_menu
        return 1
    fi
    
    local new_password=$(openssl rand -base64 16 | tr -d '=+/' | cut -c1-16)
    echo "$username:$new_password" | chpasswd
    
    success "Password reset"
    echo -e " ${C_WHITE}New Password:${C_NC} $new_password"
    pause_menu
}
