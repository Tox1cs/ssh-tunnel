# Tox1c SSH-Tunnel v3.1 Enterprise

**Ultra-high-performance, kernel-tuned, and enterprise-grade SSH Tunneling solution.**

Engineered for DevOps professionals, gamers, and network engineers requiring maximum throughput, ultra-low latency, and unbreakable stability. Optimized for Discord, gaming, and social media applications.

---

## 🚀 **Key Features**

### ⚡ **Kernel-Level Performance**
- **BBR Congestion Control**: Google's BBR algorithm with FQ qdisc for maximum bandwidth utilization
- **16MB TCP Buffers**: Optimized for 1Gbps+ links with zero packet loss
- **TCP Fast Open**: Reduces connection establishment latency by 25-40%
- **UDP Gateway**: Compiled with -O3 optimization for zero-latency forwarding
- **High Concurrency**: Handles 3000+ simultaneous connections per instance

### 🛡️ **Enterprise Security**
- **Jail Isolation**: VPN users restricted to `/usr/sbin/nologin` (no shell access)
- **SSH Hardening**: Disabled X11, agent forwarding, and unnecessary features
- **Port Stealth**: Change SSH ports instantly with automatic firewall updates
- **Input Validation**: All user inputs validated against injection attacks
- **Capability Binding**: Minimal privilege escalation with CAP_NET_BIND_SERVICE only

### 📊 **Live Monitor Pro**
- **Real-Time Dashboard**: Beautiful TUI with live metrics
- **Network Visualization**: Activity bars and speed graphs
- **System Metrics**: CPU, RAM, disk, and load average monitoring
- **User Tracking**: See connected users and their session status
- **Service Health**: Real-time SSH and UDP gateway status

### 🎮 **Gaming & Social Media Optimized**
- **Ultra-Low Latency**: Optimized for Discord, gaming, and streaming
- **Adaptive QoS**: Automatic traffic prioritization
- **Connection Pooling**: Efficient connection reuse
- **Bandwidth Optimization**: Intelligent buffer management

---

## 📋 **System Requirements**

- **OS**: Ubuntu 20.04 / 22.04 / 24.04 (Debian-based)
- **CPU**: 2+ cores recommended
- **RAM**: 512MB minimum, 2GB+ recommended
- **Disk**: 500MB free space
- **Network**: Root access required for installation

---

## 📥 **Installation**

### Quick Install (One-Line)

```bash
sudo bash <(curl -Ls https://raw.githubusercontent.com/Tox1cs/ssh-tunnel/main/install.sh)
```

### Manual Install

```bash
git clone https://github.com/Tox1cs/ssh-tunnel.git
cd ssh-tunnel
sudo bash install.sh
```

### Post-Installation

After installation, access the manager:

```bash
sudo tox1c
```
