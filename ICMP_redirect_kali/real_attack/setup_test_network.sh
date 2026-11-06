#!/bin/bash

# Colors
RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}Please run as root${NC}"
    exit 1
fi

# Install required packages
echo -e "${YELLOW}[*] Installing required packages...${NC}"
apt update
apt install -y hostapd dnsmasq net-tools wireless-tools tcpdump tmux

# Stop network services
systemctl stop NetworkManager
systemctl stop hostapd
systemctl stop dnsmasq

# Get wireless interface
echo -e "\n${YELLOW}[*] Available wireless interfaces:${NC}"
iwconfig
echo
read -p "Enter wireless interface: " WIFI_IFACE

# Configure interface
ip link set $WIFI_IFACE down
ip addr flush dev $WIFI_IFACE
ip link set $WIFI_IFACE up
ip addr add 10.0.0.1/24 dev $WIFI_IFACE

# Create hostapd config
cat > /etc/hostapd/hostapd.conf << EOF
interface=$WIFI_IFACE
driver=nl80211
ssid=TestNetwork
hw_mode=g
channel=1
ieee80211n=0
wmm_enabled=0
auth_algs=1
wpa=2
wpa_passphrase=test12345
wpa_key_mgmt=WPA-PSK
wpa_pairwise=TKIP
rsn_pairwise=CCMP
EOF

# Create dnsmasq config
cat > /etc/dnsmasq.conf << EOF
interface=$WIFI_IFACE
dhcp-range=10.0.0.10,10.0.0.50,12h
dhcp-option=3,10.0.0.1
no-resolv
no-poll
EOF

# Start services
hostapd /etc/hostapd/hostapd.conf &
sleep 2
dnsmasq

# Setup attacker IP
ip addr add 10.0.0.100/24 dev $WIFI_IFACE

echo -e "${GREEN}[+] Network setup complete!${NC}"
echo -e "${YELLOW}[*] Network: TestNetwork${NC}"
echo -e "${YELLOW}[*] Password: test12345${NC}"
echo -e "${YELLOW}[*] Router IP: 10.0.0.1${NC}"
echo -e "${YELLOW}[*] Attacker IP: 10.0.0.100${NC}"