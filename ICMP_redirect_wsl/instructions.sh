#!/bin/bash

# Print instructions
print_instructions() {
    clear
    echo -e "\033[1;35m=========================================\033[0m"
    echo -e "\033[1;35m        ICMP Redirect Attack Demo        \033[0m"
    echo -e "\033[1;35m=========================================\033[0m\n"

    echo -e "\033[1;33mPreliminary Step: Make Scripts Executable\033[0m"
    echo -e "   Run these commands:"
    echo -e "   1. chmod +x *.sh     (make shell scripts executable)"
    echo -e "   2. chmod +x *.py     (make Python scripts executable)\n"

    echo -e "\033[1;33mStep 1: Clean Up Previous Configuration\033[0m"
    echo -e "   Run: sudo ./thorough_cleanup.sh"
    echo -e "   This will remove any existing network setup\n"

    echo -e "\033[1;33mStep 2: Set Up WSL Network\033[0m"
    echo -e "   Run: sudo ./wsl_setup.sh"
    echo -e "   This will configure the required network topology\n"

    echo -e "\033[1;33mStep 3: Verify Network Configuration\033[0m"
    echo -e "   Run: sudo python3 verify_connectivity.py"
    echo -e "   Ensure all connections are properly established\n"

    echo -e "\033[1;33mStep 4: Open Mitigation Terminal\033[0m"
    echo -e "   Open a new terminal window"
    echo -e "   Run: sudo ./mitigation.sh"
    echo -e "   Keep this terminal open for toggling protection\n"

    echo -e "\033[1;33mStep 5: Launch Monitor\033[0m"
    echo -e "   Run: sudo ./monitor.sh"
    echo -e "   A tmux session will open showing a monitoring dashboard with:\n"

    echo -e "\033[1;36mDashboard Layout (6 panes - 3 rows × 2 columns):\033[0m"
    echo -e "┌────────────────────────┬────────────────────────┐"
    echo -e "│ Routing Table Monitor  │ Network Topology       │"
    echo -e "│ - Route to 8.8.8.8     │ (ASCII diagram)        │"
    echo -e "│ - ICMP redirect status │                        │"
    echo -e "├────────────────────────┼────────────────────────┤"
    echo -e "│ ICMP Traffic Monitor   │ Attacker Traffic       │"
    echo -e "│ (tcpdump output)       │ Monitor                │"
    echo -e "├────────────────────────┼────────────────────────┤"
    echo -e "│ Ping Statistics        │ Attack Script Status   │"
    echo -e "│ (ping to 8.8.8.8)      │ (Python script output) │"
    echo -e "└────────────────────────┴────────────────────────┘\n"

    echo -e "\033[1;36mWhat you'll see in each pane:\033[0m"
    echo -e "1. \033[1;32mTop Left:\033[0m"
    echo -e "   - Current route to 8.8.8.8"
    echo -e "   - Full routing table"
    echo -e "   - \033[1;32mGreen\033[0m = Legitimate route via 192.168.1.1"
    echo -e "   - \033[1;31mRed\033[0m = Hijacked route via 192.168.1.20"
    echo -e "   - ICMP redirect status (ENABLED/DISABLED)\n"

    echo -e "2. \033[1;32mTop Right:\033[0m"
    echo -e "   - Network topology diagram"
    echo -e "   - Shows connections between:"
    echo -e "     Victim → Gateway → Internet"
    echo -e "     └─── Attacker ───┘\n"

    echo -e "3. \033[1;32mMiddle Left:\033[0m"
    echo -e "   - Live ICMP traffic capture"
    echo -e "   - Shows ICMP redirect packets in \033[1;31mred\033[0m"
    echo -e "   - Shows normal ICMP traffic in \033[1;32mgreen\033[0m\n"

    echo -e "4. \033[1;32mMiddle Right:\033[0m"
    echo -e "   - Attacker's traffic monitor"
    echo -e "   - Shows all packets through attacker's interface\n"

    echo -e "5. \033[1;32mBottom Left:\033[0m"
    echo -e "   - Live ping statistics to 8.8.8.8"
    echo -e "   - Shows response times and packet loss\n"

    echo -e "6. \033[1;32mBottom Right:\033[0m"
    echo -e "   - Attack script execution status"
    echo -e "   - Shows if attack is blocked or successful"
    echo -e "   - Displays current routing status\n"

    echo -e "\033[1;36mKey indicators to watch:\033[0m"
    echo -e "- Top Left: Route changes and ICMP redirect status"
    echo -e "- Middle Left: ICMP redirect packets (in red)"
    echo -e "- Bottom Right: Attack success/failure messages\n"

    echo -e "\033[1;36mObserve the Effects:\033[0m"
    echo -e "   - When protected: ICMP redirects will be blocked"
    echo -e "   - When vulnerable: Route will be hijacked to 192.168.1.20"
    echo -e "   - Watch the monitor screen for color changes indicating attack success/failure\n"

    echo -e "\033[1;31mNote: For educational purposes only!\033[0m"
    echo -e "\033[1;31mDo not use on production networks.\033[0m\n"

    echo -e "\033[1;36mPress Enter to continue...\033[0m"
    read
}

# Call the function
print_instructions