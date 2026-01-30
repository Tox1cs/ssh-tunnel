#!/bin/bash

source "$(dirname "${BASH_SOURCE[0]}")/../lib/colors.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../ui/render.sh"

get_cpu_usage() {
    local cpu_line=$(head -n1 /proc/stat)
    local user=$(echo $cpu_line | awk '{print $2}')
    local nice=$(echo $cpu_line | awk '{print $3}')
    local system=$(echo $cpu_line | awk '{print $4}')
    local idle=$(echo $cpu_line | awk '{print $5}')
    
    local total=$((user + nice + system + idle))
    local used=$((user + nice + system))
    
    if [ $total -gt 0 ]; then
        echo $((used * 100 / total))
    else
        echo 0
    fi
}

get_memory_usage() {
    local mem_info=$(free -b | grep Mem)
    local total=$(echo $mem_info | awk '{print $2}')
    local used=$(echo $mem_info | awk '{print $3}')
    
    if [ $total -gt 0 ]; then
        echo $((used * 100 / total))
    else
        echo 0
    fi
}

get_memory_mb() {
    local mem_info=$(free -m | grep Mem)
    echo "$mem_info" | awk '{print $3 "/" $2}'
}

get_network_speed() {
    local interface=$1
    local rx_file="/sys/class/net/$interface/statistics/rx_bytes"
    local tx_file="/sys/class/net/$interface/statistics/tx_bytes"
    
    if [ ! -f "$rx_file" ] || [ ! -f "$tx_file" ]; then
        echo "0 0"
        return
    fi
    
    local rx1=$(cat "$rx_file" 2>/dev/null || echo 0)
    local tx1=$(cat "$tx_file" 2>/dev/null || echo 0)
    
    sleep 1
    
    local rx2=$(cat "$rx_file" 2>/dev/null || echo 0)
    local tx2=$(cat "$tx_file" 2>/dev/null || echo 0)
    
    local rx_speed=$(( (rx2 - rx1) / 1024 ))
    local tx_speed=$(( (tx2 - tx1) / 1024 ))
    
    echo "$rx_speed $tx_speed"
}

get_service_status() {
    local service=$1
    
    if systemctl is-active --quiet "$service" 2>/dev/null; then
        echo "ACTIVE"
    else
        echo "OFFLINE"
    fi
}

get_active_users() {
    ps -eo user,cmd 2>/dev/null | grep 'sshd: ' | grep -v 'root' | grep -v 'grep' | awk '{print $1}' | sort | uniq -c | awk '{print $2}' | wc -l
}

get_active_users_list() {
    ps -eo user,cmd 2>/dev/null | grep 'sshd: ' | grep -v 'root' | grep -v 'grep' | awk '{print $1}' | sort | uniq
}

get_uptime() {
    local uptime_seconds=$(cat /proc/uptime | awk '{print int($1)}')
    local days=$((uptime_seconds / 86400))
    local hours=$(( (uptime_seconds % 86400) / 3600 ))
    local minutes=$(( (uptime_seconds % 3600) / 60 ))
    
    printf "%dd %dh %dm" $days $hours $minutes
}

get_load_average() {
    cat /proc/loadavg | awk '{print $1, $2, $3}'
}

get_disk_usage() {
    local path=${1:-/}
    df -h "$path" | tail -1 | awk '{print $3 "/" $2 " (" $5 ")"}'
}
