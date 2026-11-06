# Get default interface name
DEFAULT_IF=$(ip route | grep default | awk '{print $5}')
echo -e "${YELLOW}[*] Default interface: ${DEFAULT_IF}${NC}"

# Create namespaces
echo -e "${YELLOW}[*] Creating network namespaces...${NC}"
for NS in victim attacker gateway; do
    ip netns add $NS
    ip netns exec $NS ip link set lo up
done

# Create bridge
echo -e "${YELLOW}[*] Creating bridge...${NC}"
ip link add br0 type bridge
ip link set br0 up
ip addr add 192.168.1.254/24 dev br0

# Create and configure veth pairs
echo -e "${YELLOW}[*] Creating veth pairs...${NC}"

# Victim pair
ip link add v-eth0 type veth peer name v-br0
ip link set v-eth0 netns victim
ip link set v-br0 master br0
ip link set v-br0 up

# Attacker pair
ip link add a-eth0 type veth peer name a-br0
ip link set a-eth0 netns attacker
ip link set a-br0 master br0
ip link set a-br0 up

# Gateway pair
ip link add gw-eth0 type veth peer name gw-br0
ip link set gw-eth0 netns gateway
ip link set gw-br0 master br0
ip link set gw-br0 up

# Configure IP addresses
echo -e "${YELLOW}[*] Configuring IP addresses...${NC}"
ip netns exec victim ip addr add 192.168.1.10/24 dev v-eth0
ip netns exec attacker ip addr add 192.168.1.20/24 dev a-eth0
ip netns exec gateway ip addr add 192.168.1.1/24 dev gw-eth0

# Bring up interfaces
echo -e "${YELLOW}[*] Bringing up interfaces...${NC}"
ip netns exec victim ip link set v-eth0 up
ip netns exec attacker ip link set a-eth0 up
ip netns exec gateway ip link set gw-eth0 up

# Configure routing
echo -e "${YELLOW}[*] Configuring routing...${NC}"
ip netns exec victim ip route add default via 192.168.1.1
ip netns exec attacker ip route add default via 192.168.1.1
ip netns exec gateway ip route add default via 192.168.1.254

# Enable IP forwarding for gateway
echo -e "${YELLOW}[*] Configuring IP forwarding...${NC}"
ip netns exec gateway sysctl -w net.ipv4.ip_forward=1 > /dev/null
sysctl -w net.ipv4.ip_forward=1 > /dev/null

# Configure NAT
echo -e "${YELLOW}[*] Configuring NAT...${NC}"
iptables -t nat -A POSTROUTING -s 192.168.1.0/24 -o $DEFAULT_IF -j MASQUERADE
ip netns exec gateway iptables -t nat -A POSTROUTING -o gw-eth0 -j MASQUERADE

# Verify setup
echo -e "\n${CYAN}[*] Verifying setup...${NC}"
echo -e "${YELLOW}[*] Interfaces in victim namespace:${NC}"
ip netns exec victim ip addr show
echo -e "\n${YELLOW}[*] Interfaces in gateway namespace:${NC}"
ip netns exec gateway ip addr show
echo -e "\n${YELLOW}[*] Routing in victim namespace:${NC}"
ip netns exec victim ip route

# Test connectivity
echo -e "\n${CYAN}[*] Testing connectivity...${NC}"
if ip netns exec victim ping -c 1 -W 2 192.168.1.1 > /dev/null 2>&1; then
    echo -e "${GREEN}[+] Local network connectivity: OK${NC}"
else
    echo -e "${RED}[-] Local network connectivity: FAILED${NC}"
fi

if ip netns exec victim ping -c 1 -W 2 8.8.8.8 > /dev/null 2>&1; then
    echo -e "${GREEN}[+] Internet connectivity: OK${NC}"
else
    echo -e "${RED}[-] Internet connectivity: FAILED${NC}"
fi

echo -e "\n${GREEN}[+] Setup completed!${NC}"