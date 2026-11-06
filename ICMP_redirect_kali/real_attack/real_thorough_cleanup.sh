#!/bin/bash

# Colors
RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Check for root privileges
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}Please run as root${NC}"
    exit 1
fi

echo -e "${YELLOW}[*] Starting cleanup for ICMP redirect attack...${NC}"

# Kill monitoring processes
echo -e "${YELLOW}[*] Killing monitoring processes...${NC}"
pkill -f "real_icmp_redirect.py" 2>/dev/null || true
pkill -f "test_website.py" 2>/dev/null || true
pkill -f tcpdump 2>/dev/null || true
tmux kill-session -t monitor 2>/dev/null || true

# Reset IP forwarding
echo -e "${YELLOW}[*] Disabling IP forwarding...${NC}"
sysctl -w net.ipv4.ip_forward=0 >/dev/null

# Flush iptables
echo -e "${YELLOW}[*] Flushing iptables rules...${NC}"
iptables -F
iptables -X
iptables -t nat -F
iptables -t nat -X
iptables -P INPUT ACCEPT
iptables -P FORWARD ACCEPT
iptables -P OUTPUT ACCEPT

# Stop web server
echo -e "${YELLOW}[*] Stopping test website...${NC}"
if pgrep python3.*test_website.py >/dev/null; then
    pkill -f "test_website.py"
fi

echo -e "${GREEN}[+] Cleanup completed successfully!${NC}"
echo -e "${GREEN}[+] You can safely disconnect from the mobile hotspot now.${NC}"