# Tox1c SSH-Tunnel v3.1 Enterprise

**A high-performance, kernel-tuned, and secure SSH Tunneling solution.**

Designed for DevOps professionals and network engineers who require maximum throughput, low latency, and unbreakable stability. This is not just a script; it is a full system architecture overhaul.

## 🚀 Key Features

### ⚡ **Kernel-Level Performance**
* **BBR Congestion Control:** Automatically enables Google BBR + FQ for maximum bandwidth utilization.
* **Hyper-Speed Gateway:** Includes `badvpn-udpgw` compiled with `-O3` optimization flags for zero-latency UDP forwarding (Gaming/VoIP).
* **Kernel Tuning:** Injects high-performance `sysctl` values (16MB TCP buffers, Fast Open, MTU probing) to saturate 1Gbps+ links.
* **High Concurrency:** Service limits tuned to `LimitNOFILE=65535` to handle thousands of simultaneous connections without crashing.

### 🛡️ **Enterprise Security**
* **Stealth Mode:** Change SSH ports instantly to evade scanners. The system automatically handles Firewall (UFW) and SELinux/Permissions.
* **Jail Isolation:** VPN users are restricted to `/sbin/nologin`. They can tunnel traffic but cannot execute shell commands or browse files.
* **Permission Hardening:** Strict `755/700` permission enforcement on all binaries and config directories.

### 📊 **Live Monitor Pro**
* **Real-Time Dashboard:** A TUI (Text User Interface) written in pure Bash that visualizes:
    * Live Upload/Download Speed (KB/s)
    * CPU & RAM Utilization Bars
    * Active Connected Users
    * Service Health Status

---

## 📥 Installation

Run this one-line command on a fresh **Ubuntu 20.04 / 22.04 / 24.04** server.
*(Must be run as root)*

```bash
git clone https://github.com/Tox1cs/ssh-tunnel.git && cd ssh-tunnel && chmod +x install.sh && ./install.sh
