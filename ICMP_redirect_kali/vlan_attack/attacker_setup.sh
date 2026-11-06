#!/bin/bash
# attacker_setup.sh

# Colors
RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Configuration
NAT_INTERFACE="eth0"      # NAT adapter for internet
HOST_INTERFACE="eth1"     # Host-only adapter for attack network
ATTACKER_IP="192.168.201.20"
GATEWAY_IP="192.168.201.2"
NETWORK="192.168.201.0/24"

if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}Please run as root${NC}"
    exit 1
fi

# Status check function
check_status() {
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}[+] $1 successful${NC}"
    else
        echo -e "${RED}[-] $1 failed${NC}"
        exit 1
    fi
}

# Backup current network state
backup_network_state() {
    echo -e "${YELLOW}[*] Backing up current network state...${NC}"
    mkdir -p /root/network_backup
    ip addr show > /root/network_backup/ip_addr.bak
    ip route show > /root/network_backup/ip_route.bak
    iptables-save > /root/network_backup/iptables.bak
    sysctl net.ipv4.ip_forward > /root/network_backup/ip_forward.bak
}

echo -e "${YELLOW}[*] Configuring Kali (Attacker) Network...${NC}"

# 1. Backup current state
backup_network_state

# 2. Install required packages
echo -e "${YELLOW}[*] Installing required packages...${NC}"
apt-get update -qq
apt-get install -y net-tools tcpdump scapy python3-scapy -qq
check_status "Package installation"

# 3. Configure network interfaces
echo -e "${YELLOW}[*] Configuring network interfaces...${NC}"

# Flush existing IP configuration on host interface
ip addr flush dev $HOST_INTERFACE

# Configure host-only interface
ip link set $HOST_INTERFACE down
ip addr add $ATTACKER_IP/24 dev $HOST_INTERFACE
ip link set $HOST_INTERFACE up
check_status "Host-only interface configuration"

# Add specific route for gateway
ip route add $GATEWAY_IP/32 dev $HOST_INTERFACE
ip route add $NETWORK dev $HOST_INTERFACE

# Verify connectivity
echo -e "${YELLOW}[*] Verifying network configuration...${NC}"
echo -e "Interface status:"
ip addr show $HOST_INTERFACE
echo -e "\nRouting table:"
ip route show
echo -e "\nTesting gateway connectivity..."
ping -c 3 $GATEWAY_IP

# 4. Enable IP forwarding
echo -e "${YELLOW}[*] Enabling IP forwarding...${NC}"
echo 1 > /proc/sys/net/ipv4/ip_forward
sysctl -w net.ipv4.ip_forward=1 >/dev/null 2>&1

# 5. Enable promiscuous mode
echo -e "${YELLOW}[*] Enabling promiscuous mode...${NC}"
ip link set $HOST_INTERFACE promisc on
check_status "Promiscuous mode"

# 6. Configure ICMP redirects
echo -e "${YELLOW}[*] Configuring ICMP redirects...${NC}"
for interface in /proc/sys/net/ipv4/conf/*/accept_redirects; do
    echo 1 > $interface
done
for interface in /proc/sys/net/ipv4/conf/*/send_redirects; do
    echo 1 > $interface
done
check_status "ICMP redirects"

# 7. Add firewall rules (without flushing existing)
echo -e "${YELLOW}[*] Configuring firewall rules...${NC}"
iptables -A FORWARD -j ACCEPT 2>/dev/null || true
iptables -A INPUT -p icmp -j ACCEPT 2>/dev/null || true
check_status "IPTables configuration"

# 8. Show configuration
echo -e "\n${GREEN}[+] Attacker Configuration:${NC}"
echo -e "${YELLOW}------------------------${NC}"
echo -e "Interface: $HOST_INTERFACE"
ip addr show $HOST_INTERFACE
echo -e "\nRouting Table:"
ip route show
echo -e "\nIP Forwarding Status:"
cat /proc/sys/net/ipv4/ip_forward
echo -e "${YELLOW}------------------------${NC}"

echo -e "\n${GREEN}[+]