#!/bin/bash

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Configuration
NAT_INTERFACE="enp0s3"
HOST_INTERFACE="enp0s8"
BACKUP_DIR="/root/network_backup"

# Check root
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}Please run as root${NC}"
    exit 1
fi

# Find most recent backup
get_latest_backup() {
    local latest_backup=$(ls -td $BACKUP_DIR/*/ 2>/dev/null | head -1)
    if [ -z "$latest_backup" ]; then
        echo -e "${RED}[!] No backup directory found${NC}"
        exit 1
    fi
    echo "$latest_backup"
}

# Confirm cleanup
confirm_cleanup() {
    echo -e "${YELLOW}[?] This will restore your network settings to the previous state.${NC}"
    echo -e "${YELLOW}[?] Continue? (y/N)${NC}"
    read -r response
    if [[ ! "$response" =~ ^[Yy]$ ]]; then
        echo -e "${RED}[!] Cleanup cancelled${NC}"
        exit 0
    fi
}

# Restore previous netplan configuration
restore_netplan() {
    local backup_dir=$1
    echo -e "${YELLOW}[*] Restoring netplan configuration...${NC}"
    
    if [ -f "$backup_dir/00-installer-config.yaml" ]; then
        cp "$backup_dir/00-installer-config.yaml" /etc/netplan/
        netplan apply
        echo -e "${GREEN}[+] Restored original netplan configuration${NC}"
    else
        echo -e "${RED}[!] No netplan backup found${NC}"
    fi
}

# Restore previous sysctl settings
restore_sysctl() {
    local backup_dir=$1
    echo -e "${YELLOW}[*] Restoring sysctl configuration...${NC}"
    
    if [ -f "$backup_dir/sysctl.conf" ]; then
        cp "$backup_dir/sysctl.conf" /etc/sysctl.conf
        sysctl -p
        echo -e "${GREEN}[+] Restored original sysctl configuration${NC}"
    else
        echo -e "${RED}[!] No sysctl backup found${NC}"
    fi
}

# Restore previous firewall rules
restore_firewall() {
    local backup_dir=$1
    echo -e "${YELLOW}[*] Restoring firewall rules...${NC}"
    
    if [ -f "$backup_dir/iptables.bak" ]; then
        iptables-restore < "$backup_dir/iptables.bak"
        if dpkg -l | grep -q "iptables-persistent"; then
            netfilter-persistent save
        fi
        echo -e "${GREEN}[+] Restored original firewall rules${NC}"
    else
        echo -e "${RED}[!] No iptables backup found${NC}"
    fi
}

# Remove gateway service
cleanup_service() {
    echo -e "${YELLOW}[*] Removing network interface service...${NC}"
    if systemctl is-active --quiet network-interface-setup; then
        systemctl stop network-interface-setup
        systemctl disable network-interface-setup
        rm -f /etc/systemd/system/network-interface-setup.service
        rm -f /usr/local/bin/network-setup.sh
        systemctl daemon-reload
        echo -e "${GREEN}[+] Removed network interface service${NC}"
    fi
}

# Cleanup backup directories
cleanup_backups() {
    echo -e "${YELLOW}[*] Do you want to remove backup directories? (y/N)${NC}"
    read -r response
    if [[ "$response" =~ ^[Yy]$ ]]; then
        rm -rf "$BACKUP_DIR"
        echo -e "${GREEN}[+] Removed backup directories${NC}"
    else
        echo -e "${YELLOW}[*] Keeping backup directories in $BACKUP_DIR${NC}"
    fi
}

# Main execution
echo -e "${YELLOW}[*] Starting Gateway Cleanup...${NC}"

# Get latest backup directory
LATEST_BACKUP=$(get_latest_backup)
echo -e "${YELLOW}[*] Using backup from: $LATEST_BACKUP${NC}"

# Confirm before proceeding
confirm_cleanup

# Perform restoration
restore_netplan "$LATEST_BACKUP"
restore_sysctl "$LATEST_BACKUP"
restore_firewall "$LATEST_BACKUP"
cleanup_service

# Reset interface settings
echo -e "${YELLOW}[*] Resetting interface settings...${NC}"
ip link set $HOST_INTERFACE promisc off
ip link set $HOST_INTERFACE multicast off

# Ask about cleaning up backups
cleanup_backups

# Verify restoration
echo -e "\n${GREEN}[+] Network Configuration After Cleanup:${NC}"
echo -e "${YELLOW}------------------------${NC}"
echo -e "NAT Interface: $NAT_INTERFACE"
ip addr show $NAT_INTERFACE
echo -e "\nHost Interface: $HOST_INTERFACE"
ip addr show $HOST_INTERFACE
echo -e "\nRouting Table:"
ip route show
echo -e "\nFirewall Rules:"
iptables -L
echo -e "${YELLOW}------------------------${NC}"

echo -e "\n${GREEN}[+] Cleanup completed! Original network settings restored.${NC}"
echo -e "${YELLOW}[*] Please reboot your system to ensure all changes take effect.${NC}"
echo -e "${YELLOW}[*] If you experience any issues after reboot, your backup files are preserved in: $LATEST_BACKUP${NC}"