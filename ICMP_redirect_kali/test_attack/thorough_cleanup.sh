#!/bin/bash

if [ "$EUID" -ne 0 ]; then 
    echo -e "\033[1;31mError: Please run as root\033[0m"
    exit 1
fi

echo "Performing thorough cleanup..."

# Stop any running tmux sessions
tmux kill-server 2>/dev/null || true

# Kill any running tcpdump or ping processes
pkill -f tcpdump
pkill -f ping

# Remove all network namespaces
for ns in $(ip netns list | awk '{print $1}'); do
    echo "Removing namespace: $ns"
    ip netns exec $ns ip link del dev v-eth0 2>/dev/null || true
    ip netns exec $ns ip link del dev a-eth0 2>/dev/null || true
    ip netns exec $ns ip link del dev gw-eth0 2>/dev/null || true
    ip netns del $ns
done

# Remove all veth pairs and bridges
echo "Removing interfaces..."
ip link del v-eth0 2>/dev/null || true
ip link del a-eth0 2>/dev/null || true
ip link del gw-eth0 2>/dev/null || true
ip link del br0 2>/dev/null || true

# Clean up iptables
echo "Cleaning iptables..."
iptables -F
iptables -t nat -F
iptables -X
iptables -t nat -X
iptables -P INPUT ACCEPT
iptables -P FORWARD ACCEPT
iptables -P OUTPUT ACCEPT

# Reset sysctl settings
echo "Resetting sysctl settings..."
sysctl -w net.ipv4.ip_forward=0
sysctl -w net.ipv4.conf.all.accept_redirects=0
sysctl -w net.ipv4.conf.default.accept_redirects=0

# Remove netns configuration files
rm -rf /etc/netns/* 2>/dev/null || true

# Flush routing cache
ip route flush cache

echo "Cleanup completed!"
sleep 2