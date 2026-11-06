#!/bin/bash

# Exit on error
set -e

echo "Setting up network for WSL environment..."

# 1. Cleanup
echo "Cleaning up existing configuration..."
for NS in victim attacker gateway; do
    sudo ip netns del $NS 2>/dev/null || true
done

sudo ip link del v-eth0 2>/dev/null || true
sudo ip link del a-eth0 2>/dev/null || true
sudo ip link del gw-eth0 2>/dev/null || true
sudo ip link del br0 2>/dev/null || true

# 2. Get WSL interface name
WSL_IF=$(ip route | grep default | awk '{print $5}')
echo "WSL interface: $WSL_IF"

# 3. Create namespaces
echo "Creating network namespaces..."
for NS in victim attacker gateway; do
    sudo ip netns add $NS
    sudo ip netns exec $NS ip link set lo up
done

# 4. Create bridge
echo "Creating bridge..."
sudo ip link add br0 type bridge
sudo ip link set br0 up
sudo ip addr add 192.168.1.254/24 dev br0

# 5. Create and configure veth pairs
echo "Creating veth pairs..."
# Victim pair
sudo ip link add v-eth0 type veth peer name v-br0
sudo ip link set v-eth0 netns victim
sudo ip link set v-br0 master br0
sudo ip link set v-br0 up

# Attacker pair
sudo ip link add a-eth0 type veth peer name a-br0
sudo ip link set a-eth0 netns attacker
sudo ip link set a-br0 master br0
sudo ip link set a-br0 up

# Gateway pair
sudo ip link add gw-eth0 type veth peer name gw-br0
sudo ip link set gw-eth0 netns gateway
sudo ip link set gw-br0 master br0
sudo ip link set gw-br0 up

# 6. Configure IP addresses
echo "Configuring IP addresses..."
sudo ip netns exec victim ip addr add 192.168.1.10/24 dev v-eth0
sudo ip netns exec attacker ip addr add 192.168.1.20/24 dev a-eth0
sudo ip netns exec gateway ip addr add 192.168.1.1/24 dev gw-eth0

# 7. Bring up interfaces
echo "Bringing up interfaces..."
sudo ip netns exec victim ip link set v-eth0 up
sudo ip netns exec attacker ip link set a-eth0 up
sudo ip netns exec gateway ip link set gw-eth0 up

# 8. Configure routing
echo "Configuring routing..."
sudo ip netns exec victim ip route add default via 192.168.1.1
sudo ip netns exec attacker ip route add default via 192.168.1.1
sudo ip netns exec gateway ip route add default via 192.168.1.254

# 9. Enable IP forwarding
echo "Enabling IP forwarding..."
sudo sysctl -w net.ipv4.ip_forward=1
sudo ip netns exec gateway sysctl -w net.ipv4.ip_forward=1

# 10. Configure NAT
echo "Configuring NAT..."
# Clear existing rules
sudo iptables -t nat -F
sudo iptables -F FORWARD
sudo ip netns exec gateway iptables -t nat -F
sudo ip netns exec gateway iptables -F FORWARD

# Add NAT rules
sudo iptables -t nat -A POSTROUTING -o $WSL_IF -j MASQUERADE
sudo iptables -A FORWARD -i br0 -j ACCEPT
sudo iptables -A FORWARD -o br0 -j ACCEPT

sudo ip netns exec gateway iptables -t nat -A POSTROUTING -o gw-eth0 -j MASQUERADE
sudo ip netns exec gateway iptables -A FORWARD -j ACCEPT

# 11. Configure DNS
echo "Configuring DNS..."
for NS in victim attacker gateway; do
    sudo mkdir -p /etc/netns/$NS
    echo "nameserver 8.8.8.8" | sudo tee /etc/netns/$NS/resolv.conf
done

# 12. Verify setup
echo -e "\nVerifying setup..."
echo "Interfaces in victim namespace:"
sudo ip netns exec victim ip addr show
echo -e "\nInterfaces in gateway namespace:"
sudo ip netns exec gateway ip addr show
echo -e "\nRouting in victim namespace:"
sudo ip netns exec victim ip route
echo -e "\nTesting connectivity..."
sudo ip netns exec victim ping -c 1 192.168.1.1

echo "Setup completed!"
