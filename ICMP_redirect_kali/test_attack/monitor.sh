#!/bin/bash

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo -e "\033[1;31mError: Please run as root\033[0m"
    exit 1
fi

# Ensure victim namespace exists
if ! ip netns list | grep -q "victim"; then
    echo -e "\033[1;31mError: victim namespace not found. Please run kali_setup.sh first.\033[0m"
    exit 1
fi

# Kill existing tmux session if it exists
tmux kill-session -t monitor 2>/dev/null

# Create new tmux session
tmux new-session -d -s monitor

# Configure main window (Network Monitor)
tmux rename-window -t monitor 'Network-Monitor'

# Create a 2x3 layout
tmux split-window -h
tmux split-window -h
tmux select-pane -t 0
tmux split-window -v
tmux select-pane -t 2
tmux split-window -v
tmux select-pane -t 4
tmux split-window -v

# Configure panes
# Pane 0 (Top Left): Enhanced Victim's Routing Table with colors
tmux select-pane -t 0
tmux send-keys "echo -e '\033[1;36mVictim Routing Table Monitor:\033[0m' && while true; do 
    clear
    echo -e '\033[1;33m=== Route to Target (8.8.8.8) ===\033[0m'
    route_output=\$(ip netns exec victim ip route get 8.8.8.8 2>/dev/null)
    if [[ \$route_output == *'via 192.168.1.20'* ]]; then
        echo -e '\033[1;31m[ALERT] Route hijacked by attacker!\033[0m'
        echo -e '\033[1;31m'\"\$route_output\"'\033[0m'
    elif [[ \$route_output == *'via 192.168.1.1'* ]]; then
        echo -e '\033[1;32m[SECURE] Using legitimate gateway\033[0m'
        echo -e '\033[1;32m'\"\$route_output\"'\033[0m'
    else
        echo -e '\033[1;33m'\"\$route_output\"'\033[0m'
    fi

    echo -e '\n\033[1;33m=== Full Routing Table ===\033[0m'
    while IFS= read -r line; do
        if [[ \$line == *'192.168.1.20'* ]]; then
            echo -e '\033[1;31m'\"\$line\"'\033[0m'
        elif [[ \$line == *'192.168.1.1'* ]]; then
            echo -e '\033[1;32m'\"\$line\"'\033[0m'
        else
            echo -e '\033[1;37m'\"\$line\"'\033[0m'
        fi
    done <<< \$(ip netns exec victim ip route show)

    echo -e '\n\033[1;33m=== ICMP Redirect Status ===\033[0m'
    redirect_status=\$(ip netns exec victim sysctl -n net.ipv4.conf.all.accept_redirects)
    if [ \"\$redirect_status\" -eq 1 ]; then
        echo -e '\033[1;31m[VULNERABLE] ICMP Redirects: ENABLED\033[0m'
    else
        echo -e '\033[1;32m[PROTECTED] ICMP Redirects: DISABLED\033[0m'
    fi
    
    sleep 1
done" C-m

# Pane 1 (Top Left): Network Topology
tmux select-pane -t 1
tmux send-keys "echo -e '\033[1;36mNetwork Topology:\033[0m\n' && cat << 'EOF'
+-------------+     +-------------+     +-------------+
|   Victim    |     |   Gateway   |     |  Internet   |
|192.168.1.10 |---->|192.168.1.1  |---->|   8.8.8.8   |
+-------------+     +-------------+     +-------------+
       ^                  ^
       |                  |
       |          +-------------+
       +----------|  Attacker   |
                  |192.168.1.20 |
                  +-------------+
EOF" C-m

# Pane 2 (Top Middle): ICMP Traffic with tcpdump and colors
tmux select-pane -t 2
tmux send-keys "echo -e '\033[1;36mICMP Traffic Monitor:\033[0m' && ip netns exec victim tcpdump -i v-eth0 -n -l -v 'icmp[icmptype] = 5 or icmp[icmptype] = 8 or icmp[icmptype] = 0' | while read -r line; do if [[ \$line == *'ICMP redirect'* || \$line == *'type=5'* || \$line == *'code=host-redirect'* ]]; then echo -e '\033[1;31m'\$line'\033[0m'; else echo -e '\033[1;32m'\$line'\033[0m'; fi; done" C-m

# Pane 3 (Bottom Middle): Attacker's Traffic
tmux select-pane -t 3
tmux send-keys "echo -e '\033[1;36mAttacker Traffic Monitor:\033[0m' && ip netns exec attacker tcpdump -i a-eth0 -n -l | while read -r line; do echo -e '\033[1;33m'\$line'\033[0m'; done" C-m

# Pane 4 (Top Right): Ping Statistics
tmux select-pane -t 4
tmux send-keys "echo -e '\033[1;36mPing Statistics:\033[0m' && ip netns exec victim ping -i 1 -D 8.8.8.8 | while read -r line; do if [[ \$line == *'time='* ]]; then echo -e '\033[1;32m'\$line'\033[0m'; else echo -e '\033[1;37m'\$line'\033[0m'; fi; done" C-m

# Pane 5 (Bottom Right): Attack Script with Status
tmux select-pane -t 5
tmux send-keys "echo -e '\033[1;36mAttack Status:\033[0m' && sleep 2 && python3 icmp_redirect_attack.py 192.168.1.10 192.168.1.1 192.168.1.20 8.8.8.8" C-m

# Set all panes to be equally sized
tmux select-layout tiled

# Attach to session
tmux attach-session -t monitor
