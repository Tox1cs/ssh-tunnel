#!/bin/bash

set -e

if [ "$EUID" -ne 0 ]; then
    echo "Error: Run as root."
    exit 1
fi

echo "Uninstalling Tox1c SSH-Tunnel..."

systemctl disable --now tox1c-tunnel.service 2>/dev/null || true
rm -f /etc/systemd/system/tox1c-tunnel.service
rm -f /etc/ssh/sshd_config.d/99-tox1c.conf
rm -f /usr/local/bin/tox1c
rm -rf /opt/tox1c-sshtunnel
rm -f /etc/sysctl.d/99-tox1c-tuning.conf

systemctl restart ssh 2>/dev/null || true
systemctl daemon-reload

echo "Uninstallation Complete."
