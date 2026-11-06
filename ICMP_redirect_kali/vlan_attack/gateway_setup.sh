#!/bin/bash

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
NAT_INTERFACE="enp0s3"
HOST_INTERFACE="enp0s8"
GATEWAY_IP="192.168.201.2"
NETWORK="192.168.201.0"
NETMASK="255.255.255.0"

# Global variables
BACKUP_DIR=""
ERROR_LOG="/tmp/gateway_setup_errors.log"
SETUP_SUCCESS=true

# Error handling function
handle_error() {
    local operation=$1
    local error_msg=$2
    SETUP_SUCCESS=false
    echo -e "${RED}[!] Error during $operation${NC}"
    echo -e "${RED}[!] Error message: $error_msg${NC}"
    echo "[$(date)] Error during $operation: $error_msg" >> "$ERROR_LOG"
}

# Rollback function
rollback_changes() {
    echo -e "${YELLOW}[*] Rolling back changes...${NC}"
    
    if [ -d "$BACKUP_DIR" ]; then
        echo -e "${BLUE}[*] Restoring from backup: $BACKUP_DIR${NC}"
        
        # Restore netplan configuration
        if [ -f "$BACKUP_DIR/00-installer-config.yaml" ]; then
            cp "$BACKUP_DIR/00-installer-config.yaml" /etc/netplan/ 2>/dev/null
            netplan apply
            echo -e "${GREEN}[+] Restored netplan configuration${NC}"
        fi

        # Restore sysctl configuration
        if [ -f "$BACKUP_DIR/sysctl.conf" ]; then
            cp "$BACKUP_DIR/sysctl.conf" /etc/sysctl.conf
            sysctl -p >/dev/null 2>&1
            echo -e "${GREEN}[+] Restored sysctl configuration${NC}"
        fi

        # Restore iptables rules
        if [ -f "$BACKUP_DIR/iptables.bak" ]; then
            iptables-restore < "$BACKUP_DIR/iptables.bak"
            echo -e "${GREEN}[+] Restored iptables rules${NC}"
        fi

        # Remove added service if it was newly created
        if [ -f "$BACKUP_DIR/network-interface-setup.service.new" ]; then
            systemctl stop network-interface-setup 2>/dev/null
            systemctl disable network-interface-setup 2>/dev/null
            rm -f /etc/systemd/system/network-interface-setup.service
            rm -f /usr/local/bin/network-setup.sh
            systemctl daemon-reload
            echo -e "${GREEN}[+] Removed network interface service${NC}"
        fi

        echo -e "${GREEN}[+] Rollback complete${NC}"
        echo -e "${YELLOW}[*] Please review $ERROR_LOG for error details${NC}"
    else
        echo -e "${RED}[!] No backup directory found. Manual intervention required.${NC}"
    fi
}

# Backup function with error handling
backup_network_state() {
    echo -e "${YELLOW}[*] Creating backup of current network state...${NC}"
    BACKUP_DIR="/root/network_backup/$(date +%Y%m%d_%H%M%S)"
    
    mkdir -p "$BACKUP_DIR" || {
        handle_error "backup creation" "Failed to create backup directory"
        exit 1
    }

    # Backup with error checking
    cp /etc/netplan/00-installer-config.yaml "$BACKUP_DIR/" 2>/dev/null || echo "No existing netplan config"
    ip addr show > "$BACKUP_DIR/ip_addr.bak" || handle_error "backup" "Failed to backup IP addresses"
    ip route show > "$BACKUP_DIR/ip_route.bak" || handle_error "backup" "Failed to backup routes"
    iptables-save > "$BACKUP_DIR/iptables.bak" || handle_error "backup" "Failed to backup iptables rules"
    cp /etc/sysctl.conf "$BACKUP_DIR/" 2>/dev/null || echo "No existing sysctl.conf"

    echo -e "${GREEN}[+] Backup created in $BACKUP_DIR${NC}"
}

# Netplan setup with error handling
setup_netplan() {
    echo -e "${YELLOW}[*] Configuring netplan...${NC}"
    local config="/etc/netplan/00-installer-config.yaml"
    
    if grep -q "$HOST_INTERFACE" "$config" 2>/dev/null; then
        echo -e "${BLUE}[*] Existing netplan configuration found for $HOST_INTERFACE${NC}"
        return 0
    fi

    # Backup existing config
    cp "$config" "$BACKUP_DIR/00-installer-config.yaml.original" 2>/dev/null

    # Add new configuration
    cat >> "$config" << EOF || {
    $HOST_INTERFACE:
      addresses:
        - $GATEWAY_IP/24
      routes:
        - to: $NETWORK/24
          via: 0.0.0.0
          metric: 100
EOF
        handle_error "netplan configuration" "Failed to update netplan config"
        return 1
    }

    # Apply netplan
    netplan apply 2>/tmp/netplan_error || {
        handle_error "netplan apply" "$(cat /tmp/netplan_error)"
        return 1
    }
}

# Additional setup functions with error handling...
# [Previous setup_sysctl, setup_interface_service, and setup_firewall functions]
# Add similar error handling to each function

# Main execution
echo -e "${YELLOW}[*] Starting Gateway Setup...${NC}"
echo -e "${BLUE}[*] Logging errors to $ERROR_LOG${NC}"

# Clear previous error log
> "$ERROR_LOG"

# Execute setup steps with error handling
backup_network_state || {
    echo -e "${RED}[!] Critical error during backup. Aborting.${NC}"
    exit 1
}

# Execute each setup step and check for errors
setup_netplan
setup_sysctl
setup_interface_service
setup_firewall

# Check if any step failed
if [ "$SETUP_SUCCESS" = false ]; then
    echo -e "\n${RED}[!] Setup encountered errors${NC}"
    echo -e "${YELLOW}[*] Would you like to rollback changes? [y/N]${NC}"
    read -r response
    if [[ "$response" =~ ^[Yy]$ ]]; then
        rollback_changes
    else
        echo -e "${YELLOW}[*] Continuing with partial setup...${NC}"
    fi
fi

# Verification and final status
echo -e "\n${GREEN}[+] Gateway Configuration Status:${NC}"
echo -e "${YELLOW}------------------------${NC}"
if [ "$SETUP_SUCCESS" = true ]; then
    echo -e "${GREEN}[+] Setup completed successfully${NC}"
else
    echo -e "${RED}[!] Setup completed with errors${NC}"
    echo -e "${YELLOW}[*] Check $ERROR_LOG for details${NC}"
fi

# Display configuration summary
echo -e "\n${BLUE}[*] Current Network Configuration:${NC}"
echo -e "NAT Interface: $NAT_INTERFACE"
ip addr show $NAT_INTERFACE
echo -e "\nHost Interface: $HOST_INTERFACE"
ip addr show $HOST_INTERFACE
echo -e "\nRouting Table:"
ip route show
echo -e "\nIP Forwarding Status:"
cat /proc/sys/net/ipv4/ip_forward

# Final instructions
echo -e "\n${YELLOW}[*] Important Notes:${NC}"
echo -e "1. If you encounter issues, check $ERROR_LOG for error details"
echo -e "2. To rollback manually, restore from: $BACKUP_DIR"
echo -e "3. For manual rollback steps:"
echo -e "   - sudo cp $BACKUP_DIR/00-installer-config.yaml /etc/netplan/"
echo -e "   - sudo cp $BACKUP_DIR/sysctl.conf /etc/"
echo -e "   - sudo iptables-restore < $BACKUP_DIR/iptables.bak"
echo -e "   - sudo netplan apply"
echo -e "   - sudo sysctl -p"

if [ "$SETUP_SUCCESS" = true ]; then
    echo -e "\n${GREEN}[+] Please reboot to ensure all changes take effect${NC}"
else
    echo -e "\n${RED}[!] Please resolve errors before rebooting${NC}"
fi