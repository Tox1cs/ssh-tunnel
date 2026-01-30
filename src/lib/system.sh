#!/bin/bash

source "$(dirname "${BASH_SOURCE[0]}")/../lib/colors.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../lib/utils.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../ui/render.sh"

change_ssh_port() {
    draw_header
    draw_section_title "CHANGE SSH PORT"
    echo ""
    
    local current_port=$(grep "^Port " /etc/ssh/sshd_config 2>/dev/null | head -1 | awk '{print $2}')
    current_port=${current_port:-22}
    
    echo -e " ${C_CYAN}Current SSH Port:${C_NC} $current_port"
    echo ""
    
    read -p " New SSH Port: " new_port
    
    if ! validate_port "$new_port"; then
        error "Invalid port (1-65535)"
        pause_menu
        return 1
    fi
    
    if [ "$new_port" -lt 1024 ] && ! is_root; then
        error "Ports below 1024 require root"
        pause_menu
        return 1
    fi
    
    sed -i "s/^Port .*/Port $new_port/" /etc/ssh/sshd_config || echo "Port $new_port" >> /etc/ssh/sshd_config
    
    if ! sshd -t 2>/dev/null; then
        sed -i "s/^Port .*/Port $current_port/" /etc/ssh/sshd_config
        error "SSH config validation failed, reverted"
        pause_menu
        return 1
    fi
    
    ufw allow "$new_port"/tcp 2>/dev/null || true
    ufw delete allow "$current_port"/tcp 2>/dev/null || true
    
    systemctl restart ssh 2>/dev/null
    
    success "SSH port changed to $new_port"
    warn "Update your SSH client: ssh -p $new_port user@host"
    pause_menu
}

enable_key_auth() {
    draw_header
    draw_section_title "ENABLE SSH KEY AUTHENTICATION"
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
    
    local ssh_dir="/home/$username/.ssh"
    mkdir -p "$ssh_dir"
    chmod 700 "$ssh_dir"
    touch "$ssh_dir/authorized_keys"
    chmod 600 "$ssh_dir/authorized_keys"
    chown -R "$username:$username" "$ssh_dir"
    
    echo ""
    echo -e " ${C_YELLOW}Paste your public key (Ctrl+D when done):${C_NC}"
    cat >> "$ssh_dir/authorized_keys"
    
    success "Public key added"
    pause_menu
}

view_system_info() {
    draw_header
    draw_section_title "SYSTEM INFORMATION"
    echo ""
    
    local hostname=$(hostname)
    local kernel=$(uname -r)
    local uptime=$(cat /proc/uptime | awk '{printf "%dd %dh %dm", int($1/86400), int(($1%86400)/3600), int(($1%3600)/60)}')
    local cpu_cores=$(nproc)
    local total_mem=$(free -h | grep Mem | awk '{print $2}')
    local disk=$(df -h / | tail -1 | awk '{print $3 "/" $2}')
    
    draw_info_row "Hostname" "$hostname"
    draw_info_row "Kernel" "$kernel"
    draw_info_row "Uptime" "$uptime"
    draw_info_row "CPU Cores" "$cpu_cores"
    draw_info_row "Total Memory" "$total_mem"
    draw_info_row "Disk Usage" "$disk"
    
    echo ""
    draw_separator
    echo ""
    
    local ssh_status=$(systemctl is-active ssh 2>/dev/null || echo "unknown")
    local gw_status=$(systemctl is-active tox1c-tunnel.service 2>/dev/null || echo "unknown")
    
    draw_info_row "SSH Service" "$(draw_status_badge "$ssh_status")"
    draw_info_row "UDP Gateway" "$(draw_status_badge "$gw_status")"
    
    pause_menu
}

view_logs() {
    draw_header
    draw_section_title "SYSTEM LOGS"
    echo ""
    
    local log_file="/var/log/tox1c.log"
    
    if [ ! -f "$log_file" ]; then
        warn "No logs found"
        pause_menu
        return
    fi
    
    tail -20 "$log_file" | while IFS= read -r line; do
        echo " $line"
    done
    
    pause_menu
}

optimize_network() {
    draw_header
    draw_section_title "NETWORK OPTIMIZATION"
    echo ""
    
    msg "Applying network optimizations..."
    
    sysctl -w net.core.default_qdisc=fq 2>/dev/null
    sysctl -w net.ipv4.tcp_congestion_control=bbr 2>/dev/null
    sysctl -w net.core.rmem_max=16777216 2>/dev/null
    sysctl -w net.core.wmem_max=16777216 2>/dev/null
    sysctl -w net.ipv4.tcp_rmem="4096 87380 16777216" 2>/dev/null
    sysctl -w net.ipv4.tcp_wmem="4096 65536 16777216" 2>/dev/null
    sysctl -w net.ipv4.tcp_fastopen=3 2>/dev/null
    sysctl -w net.ipv4.ip_forward=1 2>/dev/null
    
    success "Network optimizations applied"
    pause_menu
}
