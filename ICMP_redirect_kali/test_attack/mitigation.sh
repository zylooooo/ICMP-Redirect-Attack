L#!/bin/bash

# Color codes for better readability
RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
CYAN='\033[1;36m'
NC='\033[0m' # No Color

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}[!] Error: Please run as root${NC}"
    exit 1
fi

# Function to check security status
check_security_status() {
    redirect_status=$(ip netns exec victim sysctl -n net.ipv4.conf.all.accept_redirects)
    forward_status=$(ip netns exec attacker sysctl -n net.ipv4.ip_forward)
    
    if [ "$redirect_status" -eq 0 ]; then
        echo -e "${GREEN}[+] SECURE - ICMP Redirects: DISABLED${NC}"
    else
        echo -e "${RED}[!] VULNERABLE - ICMP Redirects: ENABLED${NC}"
    fi
    
    if [ "$forward_status" -eq 0 ]; then
        echo -e "${GREEN}[+] SECURE - Attacker IP Forwarding: DISABLED${NC}"
    else
        echo -e "${RED}[!] VULNERABLE - Attacker IP Forwarding: ENABLED${NC}"
    fi
}

# Function to disable mitigations (make victim vulnerable)
disable_mitigations() {
    echo -e "${CYAN}[*] Disabling ICMP redirect attack mitigations...${NC}"
    
    # Enable IP forwarding in attacker namespace
    echo -e "${YELLOW}[>] Enabling attacker IP forwarding...${NC}"
    ip netns exec attacker sysctl -w net.ipv4.ip_forward=1 > /dev/null
    
    # Enable ICMP redirects for all interfaces in victim namespace
    echo -e "${YELLOW}[>] Enabling ICMP redirects...${NC}"
    ip netns exec victim sysctl -w net.ipv4.conf.all.accept_redirects=1 > /dev/null
    ip netns exec victim sysctl -w net.ipv4.conf.default.accept_redirects=1 > /dev/null
    ip netns exec victim sysctl -w net.ipv4.conf.v-eth0.accept_redirects=1 > /dev/null
    ip netns exec victim sysctl -w net.ipv4.conf.lo.accept_redirects=1 > /dev/null
    
    # Enable secure redirects as well
    ip netns exec victim sysctl -w net.ipv4.conf.all.secure_redirects=1 > /dev/null
    ip netns exec victim sysctl -w net.ipv4.conf.default.secure_redirects=1 > /dev/null
    ip netns exec victim sysctl -w net.ipv4.conf.v-eth0.secure_redirects=1 > /dev/null
    
    # Clear any existing iptables rules in victim namespace
    echo -e "${YELLOW}[>] Clearing firewall rules...${NC}"
    ip netns exec victim iptables -F
    ip netns exec victim iptables -X
    ip netns exec victim iptables -P INPUT ACCEPT
    ip netns exec victim iptables -P FORWARD ACCEPT
    ip netns exec victim iptables -P OUTPUT ACCEPT
    
    # Reset routing in victim namespace
    echo -e "${YELLOW}[>] Resetting routing...${NC}"
    ip netns exec victim ip route flush cache
    ip netns exec victim ip route del 8.8.8.8 via 192.168.1.20 2>/dev/null || true
    ip netns exec victim ip route add default via 192.168.1.1
    
    # Verify settings
    echo -e "${YELLOW}[*] Verifying settings...${NC}"
    check_security_status
    
    echo -e "${RED}[!] Mitigations disabled - Victim is now vulnerable to ICMP redirects!${NC}"
}

# Function to enable mitigations (make victim secure)
enable_mitigations() {
    echo -e "${CYAN}[*] Enabling ICMP redirect attack mitigations...${NC}"
    
    # Disable IP forwarding in attacker namespace
    echo -e "${YELLOW}[>] Disabling attacker IP forwarding...${NC}"
    ip netns exec attacker sysctl -w net.ipv4.ip_forward=0 > /dev/null
    
    # Disable ICMP redirects for all interfaces in victim namespace
    echo -e "${YELLOW}[>] Disabling ICMP redirects...${NC}"
    ip netns exec victim sysctl -w net.ipv4.conf.all.accept_redirects=0 > /dev/null
    ip netns exec victim sysctl -w net.ipv4.conf.default.accept_redirects=0 > /dev/null
    ip netns exec victim sysctl -w net.ipv4.conf.v-eth0.accept_redirects=0 > /dev/null
    ip netns exec victim sysctl -w net.ipv4.conf.lo.accept_redirects=0 > /dev/null
    
    # Disable secure redirects as well
    ip netns exec victim sysctl -w net.ipv4.conf.all.secure_redirects=0 > /dev/null
    ip netns exec victim sysctl -w net.ipv4.conf.default.secure_redirects=0 > /dev/null
    ip netns exec victim sysctl -w net.ipv4.conf.v-eth0.secure_redirects=0 > /dev/null
    
    # Add iptables rules to block ICMP redirects in victim namespace
    echo -e "${YELLOW}[>] Configuring firewall rules...${NC}"
    ip netns exec victim iptables -F
    ip netns exec victim iptables -A INPUT -p icmp --icmp-type redirect -j DROP
    ip netns exec victim iptables -A FORWARD -p icmp --icmp-type redirect -j DROP
    
    # Reset routing in victim namespace
    echo -e "${YELLOW}[>] Resetting routing...${NC}"
    ip netns exec victim ip route flush cache
    ip netns exec victim ip route del 8.8.8.8 via 192.168.1.20 2>/dev/null || true
    ip netns exec victim ip route add default via 192.168.1.1
    
    # Verify settings
    echo -e "${YELLOW}[*] Verifying settings...${NC}"
    check_security_status
    
    echo -e "${GREEN}[+] Mitigations enabled - Victim is now protected against ICMP redirects!${NC}"
}

# Main menu loop
while true; do
    echo -e "\n${CYAN}=== ICMP Redirect Attack Mitigation Control ===${NC}"
    echo -e "1) ${RED}Disable${NC} mitigations (make victim vulnerable)"
    echo -e "2) ${GREEN}Enable${NC} mitigations (make victim secure)"
    echo -e "3) Check current status"
    echo -e "4) Exit"
    echo -n "Select an option [1-4]: "
    read choice

    case $choice in
        1) disable_mitigations ;;
        2) enable_mitigations ;;
        3) check_security_status ;;
        4) exit 0 ;;
        *) echo -e "${RED}[!] Invalid option${NC}" ;;
    esac
done