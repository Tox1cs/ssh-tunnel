#!/bin/bash
set -e
echo "Uninstalling Tox1c SSH-Tunnel..."
systemctl disable --now tox1c-tunnel.service || true
rm -f /etc/systemd/system/tox1c-tunnel.service
rm -f /etc/ssh/sshd_config.d/99-tox1c.conf
rm -f /usr/local/bin/tox1c
rm -rf /opt/tox1c-sshtunnel
systemctl restart ssh
systemctl daemon-reload
echo "Uninstallation Complete."
