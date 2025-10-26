#!/bin/bash
set -euo pipefail

HOSTNAME="${1:-}"

if [ -z "$HOSTNAME" ]; then
    echo "Usage: $0 <hostname>"
    echo "Example: $0 hub-router"
    exit 1
fi

echo "========================================="
echo "Setting up router: $HOSTNAME"
echo "========================================="

echo "[1/7] Updating system packages..."
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get upgrade -y

echo "[2/7] Setting hostname to $HOSTNAME..."
hostnamectl set-hostname "$HOSTNAME"
echo "127.0.1.1 $HOSTNAME" >> /etc/hosts

echo "[3/7] Installing bird2..."
apt-get install -y bird2

echo "[4/7] Installing WireGuard..."
apt-get install -y wireguard wireguard-tools

echo "[5/7] Installing nftables..."
apt-get install -y nftables

echo "[6/7] Installing tshark..."
echo "wireshark-common wireshark-common/install-setuid boolean true" | debconf-set-selections
apt-get install -y tshark

echo "[7/7] enabling IP forwarding..."
echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.conf
sysctl -p

echo "========================================="
echo "Enabling services..."
echo "========================================="
systemctl enable bird
systemctl enable nftables

echo "========================================="
echo "Installation Summary"
echo "========================================="
echo "Hostname: $(hostname)"
echo "Bird version: $(bird --version 2>&1 | head -n1)"
echo "WireGuard: $(wg --version 2>&1)"
echo "nftables version: $(nft --version)"
echo "tshark version: $(tshark --version | head -n1)"

echo ""
echo "========================================="
echo "Setup complete!"
echo "========================================="
echo ""
