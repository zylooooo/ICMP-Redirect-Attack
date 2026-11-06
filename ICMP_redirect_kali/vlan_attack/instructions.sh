#!/bin/bash
# master_setup.sh
# ... (keep existing color and configuration variables) ...

print_network_diagram() {
    print_header "Network Diagram"
    cat << 'EOF'
┌─────────────────────────────────────────────────────────────┐
│                    Network Topology                         │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│            ┌──────────────┐                                 │
│            │   Internet   │                                 │
│            └──────┬───────┘                                 │
│                   │                                         │
│            ┌──────┴───────┐                                 │
│            │Gateway (VM1) │                                 │
│            │192.168.201.2 │                                 │
│            └──────┬───────┘                                 │
│                   │                                         │
│         ┌─────────┴────────┐                                │
│         │                  │                                │
│  ┌──────┴───────┐   ┌──────┴───────┐                        │
│  │ Victim (VM2) │   │Attacker (VM3)│                        │
│  │192.168.201.10│   │192.168.201.20│                        │
│  └──────────────┘   └──────────────┘                        │
│                                                             │
│ Normal Traffic Flow:  Victim → Gateway → Internet           │
│ After ICMP Redirect: Victim → Attacker → Gateway → Internet │
└─────────────────────────────────────────────────────────────┘
EOF
}

print_troubleshooting() {
    print_header "Troubleshooting Guide"
    cat << 'EOF'
Common Issues and Solutions:

1. Network Connectivity Issues:
   Problem: VMs cannot ping each other
   Solutions:
   - Check VirtualBox network settings
   - Verify IP configurations
   - Check interface status
   Commands:
   $ ip addr show
   $ ip route show
   $ systemctl restart networking

2. Gateway Issues:
   Problem: No internet access
   Solutions:
   - Verify IP forwarding
   $ cat /proc/sys/net/ipv4/ip_forward
   - Check NAT configuration
   $ iptables -L -v -n
   $ iptables -t nat -L -v -n
   - Verify routing
   $ ip route show

3. Victim Issues:
   Problem: ICMP redirects not working
   Solutions:
   - Check registry settings
   > reg query "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" /v "EnableICMPRedirect"
   - Verify firewall rules
   > netsh advfirewall firewall show rule name=all | findstr "ICMP"
   - Test ICMP connectivity
   > ping 192.168.201.1
   > ping 192.168.201.20

4. Attacker Issues:
   Problem: Fake website not accessible
   Solutions:
   - Check Apache status
   $ systemctl status apache2
   - Verify website configuration
   $ ls -l /var/www/html
   $ cat /etc/apache2/sites-available/000-default.conf
   - Check firewall rules
   $ iptables -L -v -n

5. Attack Not Working:
   Problem: No redirection happening
   Solutions:
   - Verify all MAC addresses are correct
   $ arp -a
   - Check packet forwarding
   $ tcpdump -i eth0 icmp
   - Monitor traffic
   $ wireshark -i eth0 -k

6. Logging and Debugging:
   For Gateway:
   $ tail -f /var/log/syslog
   
   For Attacker:
   $ tail -f /var/log/apache2/access.log
   $ tail -f /var/log/apache2/error.log
   
   For Victim:
   > Event Viewer > Windows Logs > System

7. Recovery Steps:
   a) Gateway Recovery:
      $ sudo ./cleanup_gateway.sh
      $ sudo ./gateway_setup.sh
   
   b) Victim Recovery:
      > toggle_icmp_redirect.bat (Option 2)
      > victim_setup.bat
   
   c) Attacker Recovery:
      $ sudo ./cleanup_attacker.sh
      $ sudo ./attacker_setup.sh

8. VirtualBox Network Issues:
   - Ensure all VMs are on the same network
   - Check "Promiscuous Mode" is allowed
   - Verify "Cable Connected" is enabled
   - Try recreating network adapters

9. Performance Issues:
   - Reduce VM resource usage
   - Monitor system resources
   $ top
   $ htop
   $ iotop
   
10. Common Error Messages:
    "Operation not permitted":
    - Run with sudo
    - Check SELinux/AppArmor

    "Connection refused":
    - Check service status
    - Verify port availability
    $ netstat -tuln

    "No route to host":
    - Check routing tables
    - Verify network connectivity
EOF
}

main() {
    check_root
    print_instructions
    print_network_diagram    # Add network diagram
    print_gateway_instructions
    print_victim_instructions
    print_attacker_instructions
    print_verification_steps
    print_attack_verification
    print_troubleshooting    # Add troubleshooting guide
    print_cleanup_instructions
}

main