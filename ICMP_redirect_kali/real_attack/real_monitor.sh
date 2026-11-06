#!/bin/bash

# Colors
RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
CYAN='\033[1;36m'
NC='\033[0m'

# Check root privileges
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}Please run as root${NC}"
    exit 1
fi

# Get network information
WIFI_IFACE=$(ip route | grep default | awk '{print $5}')
ATTACKER_IP=$(ip addr show $WIFI_IFACE | grep -oP '(?<=inet\s)\d+(\.\d+){3}')
GATEWAY_IP=$(ip route | grep default | awk '{print $3}')

# Kill existing tmux session if exists
tmux kill-session -t monitor 2>/dev/null

# Create new tmux session with 5 panes (removed attack control panel)
tmux new-session -d -s monitor
tmux split-window -h
tmux split-window -h
tmux select-pane -t 0
tmux split-window -v
tmux select-pane -t 2
tmux split-window -v

# Pane 0: Network Information and Connected Devices
tmux select-pane -t 0
tmux send-keys "echo -e '${CYAN}Network Information:${NC}'" C-m
tmux send-keys "echo -e '${YELLOW}Interface: ${NC}$WIFI_IFACE'" C-m
tmux send-keys "echo -e '${YELLOW}Attacker IP: ${NC}$ATTACKER_IP'" C-m
tmux send-keys "echo -e '${YELLOW}Gateway IP: ${NC}$GATEWAY_IP\n'" C-m
tmux send-keys "echo -e '${CYAN}Connected Devices:${NC}'" C-m
tmux send-keys "while true; do 
    clear
    echo -e '${CYAN}Network Information:${NC}'
    echo -e '${YELLOW}Interface: ${NC}$WIFI_IFACE'
    echo -e '${YELLOW}Attacker IP: ${NC}$ATTACKER_IP'
    echo -e '${YELLOW}Gateway IP: ${NC}$GATEWAY_IP\n'
    echo -e '${CYAN}Connected Devices:${NC}'
    arp-scan --interface=$WIFI_IFACE --localnet | grep -v 'Interface\|Beginning\|Ending\|packets' | 
    while read -r line; do
        if [[ \$line == *'$ATTACKER_IP'* ]]; then
            echo -e '${YELLOW}[THIS MACHINE] $line${NC}'
        elif [[ \$line == *'$GATEWAY_IP'* ]]; then
            echo -e '${YELLOW}[GATEWAY] $line${NC}'
        else
            echo -e '${GREEN}[POTENTIAL TARGET] $line${NC}'
        fi
    done
    sleep 5
done" C-m

# Pane 1: ICMP Redirect Monitor
tmux select-pane -t 1
tmux send-keys "echo -e '${CYAN}ICMP Redirect Monitor:${NC}'" C-m
tmux send-keys "tcpdump -i $WIFI_IFACE -nn -l 'icmp[icmptype] = 5' | while read -r line; do
    echo -e '${RED}[REDIRECT] $line${NC}'
done" C-m

# Pane 2: HTTP Traffic Monitor
tmux select-pane -t 2
tmux send-keys "echo -e '${CYAN}HTTP Traffic Monitor:${NC}'" C-m
tmux send-keys "tcpdump -i $WIFI_IFACE -nn -l 'tcp port 80 or tcp port 443' | while read -r line; do
    if [[ \$line == *'$ATTACKER_IP'* ]]; then
        echo -e '${RED}[INTERCEPTED] $line${NC}'
    else
        echo -e '${GREEN}[NORMAL] $line${NC}'
    fi
done" C-m

# Pane 3: Attack Status
tmux select-pane -t 3
tmux send-keys "echo -e '${CYAN}System Status:${NC}'" C-m
tmux send-keys "while true; do
    clear
    echo -e '${YELLOW}Current Time: ${NC}'$(date)
    echo -e '${YELLOW}IP Forwarding: ${NC}'$(cat /proc/sys/net/ipv4/ip_forward)
    echo -e '\n${CYAN}Active Connections:${NC}'
    netstat -tun | grep ESTABLISHED | while read -r line; do
        if [[ \$line == *'$ATTACKER_IP'* ]]; then
            echo -e '${RED}[INTERCEPTED] $line${NC}'
        else
            echo -e '${GREEN}[NORMAL] $line${NC}'
        fi
    done
    sleep 2
done" C-m

# Pane 4: Web Server Status
tmux select-pane -t 4
tmux send-keys "echo -e '${CYAN}Web Server Access Log:${NC}'" C-m
tmux send-keys "tail -f /var/log/apache2/access.log 2>/dev/null || echo 'No web server log available'" C-m

# Set all panes to be equally sized
tmux select-layout tiled

# Print instructions
echo -e "\n${CYAN}Monitor Layout:${NC}"
echo -e "${YELLOW}Top Left:${NC} Network Info & Connected Devices"
echo -e "${YELLOW}Top Middle:${NC} ICMP Redirect Monitor"
echo -e "${YELLOW}Bottom Middle:${NC} HTTP Traffic Monitor"
echo -e "${YELLOW}Top Right:${NC} System Status"
echo -e "${YELLOW}Bottom Right:${NC} Web Server Access Log"

echo -e "\n${CYAN}To launch attack in another terminal:${NC}"
echo -e "sudo python3 real_icmp_redirect.py -i $WIFI_IFACE -v TARGET_IP"

echo -e "\n${CYAN}Press Ctrl+B then D to detach from tmux${NC}"
echo -e "${CYAN}Press Ctrl+C to stop monitoring${NC}\n"

# Attach to session
tmux attach-session -t monitor