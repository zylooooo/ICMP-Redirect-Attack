#!/bin/bash

echo "Performing thorough cleanup..."

# Stop any running tmux sessions
tmux kill-server 2>/dev/null || true

# Kill any running tcpdump or ping processes
sudo pkill -f tcpdump
sudo pkill -f ping

# Remove all network namespaces
for ns in $(ip netns list | awk '{print $1}'); do
    echo "Removing namespace: $ns"
    # First, remove any interfaces in the namespace
    sudo ip netns exec $ns ip link del dev v-eth0 2>/dev/null || true
    sudo ip netns exec $ns ip link del dev a-eth0 2>/dev/null || true
    sudo ip netns exec $ns ip link del dev gw-eth0 2>/dev/null || true
    # Then delete the namespace
    sudo ip netns del $ns
done

# Remove all veth pairs and bridges
echo "Removing interfaces..."
sudo ip link del v-eth0 2>/dev/null || true
sudo ip link del a-eth0 2>/dev/null || true
sudo ip link del gw-eth0 2>/dev/null || true
sudo ip link del v-br0 2>/dev/null || true
sudo ip link del a-br0 2>/dev/null || true
sudo ip link del gw-br0 2>/dev/null || true
sudo ip link del br0 2>/dev/null || true

# Clean up iptables
echo "Cleaning iptables..."
sudo iptables -F
sudo iptables -t nat -F
sudo iptables -X
sudo iptables -t nat -X
sudo iptables -P INPUT ACCEPT
sudo iptables -P FORWARD ACCEPT
sudo iptables -P OUTPUT ACCEPT

# Reset sysctl settings
echo "Resetting sysctl settings..."
sudo sysctl -w net.ipv4.ip_forward=0
sudo sysctl -w net.ipv4.conf.all.accept_redirects=0
sudo sysctl -w net.ipv4.conf.default.accept_redirects=0

# Remove any stale netns configuration files
sudo rm -rf /etc/netns/* 2>/dev/null || true

# Flush routing cache
sudo ip route flush cache

echo "Cleanup completed!"

# Wait a moment for everything to settle
sleep 2
