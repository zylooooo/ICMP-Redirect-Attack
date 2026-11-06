#!/usr/bin/env python3

import os
import sys
import subprocess
import time
import netifaces
from dataclasses import dataclass
from typing import List, Optional

def run_cmd(cmd, description="", verbose=True):
    """Execute command and return result with proper formatting"""
    if verbose:
        print(f"\n[TEST] {description}" if description else f"\nExecuting: {cmd}")
    result = subprocess.run(cmd, shell=True, text=True, capture_output=True)
    if result.returncode == 0:
        if verbose:
            print(f"[+] Success: {result.stdout.strip()}")
        return True, result.stdout
    else:
        if verbose:
            print(f"[-] Failed: {result.stderr.strip()}")
        return False, result.stderr

@dataclass
class NetworkConfig:
    interface: str
    attacker_ip: str
    victim_ip: str
    gateway_ip: str

class NetworkVerifier:
    def __init__(self):
        self.check_root()
        self.config = None

    def check_root(self):
        if os.geteuid() != 0:
            print("[-] Script must be run as root")
            sys.exit(1)
        print("[+] Running as root")

    def configure_system(self):
        print("\n=== Configuring System Settings ===")
        settings = {
            "net.ipv4.ip_forward": "1",
            "net.ipv4.conf.all.send_redirects": "0",
            "net.ipv4.conf.all.accept_redirects": "0"
        }
        
        for setting, value in settings.items():
            success, _ = run_cmd(f"sysctl -w {setting}={value}", f"Setting {setting}")
            if not success:
                print(f"[-] Failed to configure {setting}")
                sys.exit(1)

    def get_wireless_interfaces(self) -> List[str]:
        # Simply return all active interfaces
        interfaces = []
        for iface in netifaces.interfaces():
        # Skip loopback
            if iface != 'lo':
                interfaces.append(iface)
        return interfaces

    def wait_for_connection(self, interface: str):
        print("\n[*] Please connect to your mobile hotspot now...")
        print("[*] Waiting for connection...")
        
        while True:
            if netifaces.AF_INET in netifaces.ifaddresses(interface):
                break
            time.sleep(1)

    def test_connectivity(self, ip: str, description: str) -> bool:
        success, _ = run_cmd(f"ping -c 3 -W 2 {ip}", f"Testing connection to {description}")
        return success

    def verify_network(self):
        print("[*] Starting Network Verification\n")

        # Get wireless interfaces
        interfaces = self.get_wireless_interfaces()
        if not interfaces:
            print("[-] No wireless interfaces found!")
            sys.exit(1)

        print("\n=== Available Wireless Interfaces ===")
        for iface in interfaces:
            print(f"  - {iface}")

        # Get interface selection
        interface = input("\nEnter wireless interface: ").strip()
        if interface not in interfaces:
            print("[-] Invalid interface selected!")
            sys.exit(1)

        # Configure system
        self.configure_system()

        # Ensure interface is up
        run_cmd(f"ip link set {interface} up", "Activating interface")

        # Wait for connection
        self.wait_for_connection(interface)

        # Get network information
        attacker_ip = netifaces.ifaddresses(interface)[netifaces.AF_INET][0]['addr']
        gateway_ip = netifaces.gateways()['default'][netifaces.AF_INET][0]

        print(f"\n[+] Connected successfully!")
        print(f"[+] Attacker IP: {attacker_ip}")
        print(f"[+] Gateway IP: {gateway_ip}")

        # Get victim IP
        print("\n[*] Please connect the victim machine to the same hotspot")
        victim_ip = input("Enter victim's IP address: ").strip()

        # Store configuration
        self.config = NetworkConfig(
            interface=interface,
            attacker_ip=attacker_ip,
            victim_ip=victim_ip,
            gateway_ip=gateway_ip
        )

        print("\n=== Testing Network Connectivity ===")
        
        # Test connectivity
        tests = [
            (gateway_ip, "gateway"),
            (victim_ip, "victim"),
            ("8.8.8.8", "internet")
        ]

        all_passed = True
        for ip, desc in tests:
            if not self.test_connectivity(ip, desc):
                all_passed = False

        if all_passed:
            print("\n[+] All connectivity tests passed!")
            print("[+] Setup verified successfully")
            return True
        else:
            print("\n[-] Some connectivity tests failed")
            print("[*] Please verify network configuration")
            return False

if __name__ == "__main__":
    try:
        verifier = NetworkVerifier()
        if verifier.verify_network():
            sys.exit(0)
        else:
            sys.exit(1)
    except KeyboardInterrupt:
        print("\n\n[!] Test interrupted by user")
        sys.exit(1)
    except Exception as e:
        print(f"\n\n[!] Error during testing: {e}")
        sys.exit(1)
