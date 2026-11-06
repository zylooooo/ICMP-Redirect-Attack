#!/bin/bash

# Colors
RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Configuration
INTERFACE="eth0"     # Interface used for attack

if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}Please run as root${NC}"
    exit 1
fi

echo -e "${YELLOW}[*] Starting Attacker Cleanup...${NC}"

# 1. Restore network state if backup exists
if [ -d "/root/network_backup" ]; then
    echo -e "${YELLOW}[*] Restoring original network state...${NC}"
    
    # Restore IP forwarding state
    echo -e "${YELLOW}[*] Resetting IP forwarding...${NC}"
    cat /root/network_backup/ip_forward.bak | cut -d = -f2 | tr -d ' ' > /proc/sys/net/ipv4/ip_forward
    
    # Restore iptables rules
    echo -e "${YELLOW}[*] Restoring firewall rules...${NC}"
    iptables-restore < /root/network_backup/iptables.bak
else
    # If no backup, perform basic cleanup
    echo -e "${YELLOW}[*] No backup found, performing basic cleanup...${NC}"
    
    # Disable IP forwarding
    echo 0 > /proc/sys/net/ipv4/ip_forward
    
    # Remove firewall rules
    iptables -D FORWARD -j ACCEPT 2>/dev/null || true
    iptables -D INPUT -p icmp -j ACCEPT 2>/dev/null || true
fi

# 2. Disable promiscuous mode
echo -e "${YELLOW}[*] Disabling promiscuous mode...${NC}"
ip link set $INTERFACE promisc off

# 3. Reset ICMP redirects
echo -e "${YELLOW}[*] Resetting ICMP redirects...${NC}"
for interface in /proc/sys/net/ipv4/conf/*/accept_redirects; do
    echo 0 > $interface
done
for interface in /proc/sys/net/ipv4/conf/*/send_redirects; do
    echo 0 > $interface
done

# 4. Show final configuration
echo -e "\n${GREEN}[+] Current Network Configuration:${NC}"
echo -e "${YELLOW}------------------------${NC}"
echo -e "Interface: $INTERFACE"
ip addr show $INTERFACE
echo -e "\nRouting Table:"
ip route show
echo -e "\nIP Forwarding Status:"
cat /proc/sys/net/ipv4/ip_forward
echo -e "${YELLOW}------------------------${NC}"

echo -e "\n${GREEN}[+] Cleanup complete!${NC}"

# Test network connectivity
ping -c 1 8.8.8.8 >/dev/null 2>&1
if [ $? -eq 0 ]; then
    echo -e "${GREEN}[+] Network connectivity maintained${NC}"
else
    echo -e "${RED}[-] Warning: Network connectivity lost${NC}"
fi