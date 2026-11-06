#!/usr/bin/python3
import subprocess
import time
import sys
import os
import socket
import platform
from datetime import datetime

class TerminalColors:
    def __init__(self):
        self.is_windows = sys.platform.startswith('win')
        
        if self.is_windows:
            self.PASS = '[+]'
            self.FAIL = '[-]'
            self.INFO = '[*]'
            self.WARN = '[!]'
            self.GREEN = ''
            self.RED = ''
            self.YELLOW = ''
            self.BLUE = ''
            self.RESET = ''
        else:
            self.PASS = '[✓]'
            self.FAIL = '[✗]'
            self.INFO = '[*]'
            self.WARN = '[!]'
            self.GREEN = '\033[92m'
            self.RED = '\033[91m'
            self.YELLOW = '\033[93m'
            self.BLUE = '\033[94m'
            self.RESET = '\033[0m'

class NetworkVerification:
    def __init__(self):
        self.colors = TerminalColors()
        self.network = "192.168.201"
        self.expected_hosts = {
            'victim': f"{self.network}.10",    # Windows
            'gateway': f"{self.network}.2",    # Ubuntu
            'attacker': f"{self.network}.20"   # Kali
        }
        # Determine interface based on OS
        self.interface = self._get_default_interface()
        self.own_ip = self.get_own_ip()
        self.role = self.determine_role()
        
    def _get_default_interface(self):
        """Get default network interface based on OS"""
        if self.colors.is_windows:
            return "Ethernet"
        else:
            try:
                cmd = "ip route | grep default | awk '{print $5}'"
                return subprocess.check_output(cmd, shell=True).decode().strip()
            except:
                return "eth0"  # fallback

    def print_status(self, message, status, details=""):
        timestamp = datetime.now().strftime("%H:%M:%S")
        if status:
            symbol = self.colors.GREEN + self.colors.PASS + self.colors.RESET
        else:
            symbol = self.colors.RED + self.colors.FAIL + self.colors.RESET
        
        print(f"[{timestamp}] {symbol} {message}")
        if details:
            print(f"       {self.colors.BLUE}Details:{self.colors.RESET} {details}")

    def print_section(self, title):
        print(f"\n{self.colors.YELLOW}=== {title} ==={self.colors.RESET}")

    def run_cmd(self, cmd, description=""):
        try:
            result = subprocess.run(cmd, shell=True, text=True, capture_output=True)
            success = result.returncode == 0
            output = result.stdout.strip() if success else result.stderr.strip()
            
            if description:
                self.print_status(description, success, output if output else None)
            return success, output
        except Exception as e:
            self.print_status(description, False, str(e))
            return False, str(e)

    def check_required_packages(self):
        """Verify required packages are installed"""
        self.print_section("Package Verification")
        all_passed = True

        if self.colors.is_windows:
            required_tools = {
                'ping': 'ping 127.0.0.1 -n 1',
                'tracert': 'tracert /?',
                'nslookup': 'nslookup /?',
                'powershell': 'powershell Get-Host'
            }
        else:
            required_tools = {
                'ip': 'which ip',
                'ping': 'which ping',
                'traceroute': 'which traceroute',
                'curl': 'which curl',
                'netcat': 'which nc',
                'dig': 'which dig'
            }
            
            # Additional tools based on role
            if self.role == 'gateway':
                required_tools.update({
                    'iptables': 'which iptables',
                    'tcpdump': 'which tcpdump'
                })
            elif self.role == 'attacker':
                required_tools.update({
                    'scapy': 'python3 -c "import scapy"',
                    'apache2': 'systemctl is-active apache2'
                })

        for tool, check_cmd in required_tools.items():
            success, _ = self.run_cmd(check_cmd, f"Checking {tool}")
            all_passed &= success

        return all_passed

    def get_own_ip(self):
        try:
            if self.colors.is_windows:
                cmd = "ipconfig | findstr IPv4"
                output = subprocess.check_output(cmd, shell=True).decode()
                return output.split(": ")[-1].strip()
            else:
                cmd = f"ip addr show {self.interface} | grep 'inet ' | awk '{{print $2}}' | cut -d/ -f1"
                return subprocess.check_output(cmd, shell=True).decode().strip()
        except:
            return None

    def determine_role(self):
        for role, ip in self.expected_hosts.items():
            if ip in str(self.own_ip):
                return role
        return None

    def verify_interface(self):
        self.print_section("Network Interface Verification")
        
        if self.colors.is_windows:
            success, _ = self.run_cmd("ipconfig", "Network interface status")
        else:
            success, _ = self.run_cmd(f"ip link show {self.interface}", "Network interface status")
            if success:
                success, _ = self.run_cmd(f"ip addr show {self.interface}", "IP configuration")
        return success

    def test_connectivity(self):
        self.print_section("VM Connectivity Tests")
        all_passed = True
        
        # Basic ping tests
        for host_role, host_ip in self.expected_hosts.items():
            if host_ip not in str(self.own_ip):
                if self.colors.is_windows:
                    cmd = f"ping -n 2 -w 2000 {host_ip}"
                else:
                    cmd = f"ping -c 2 -W 2 {host_ip}"
                success, _ = self.run_cmd(cmd, f"ICMP connectivity to {host_role} ({host_ip})")
                all_passed &= success

        # TCP connectivity tests (if not Windows)
        if not self.colors.is_windows:
            for host_role, host_ip in self.expected_hosts.items():
                if host_ip not in str(self.own_ip):
                    cmd = f"nc -zv -w 2 {host_ip} 80"
                    success, _ = self.run_cmd(cmd, f"TCP connectivity to {host_role} ({host_ip})")
                    all_passed &= success

        # Route verification
        if self.colors.is_windows:
            success, _ = self.run_cmd("route print", "Routing table verification")
        else:
            success, _ = self.run_cmd("ip route show", "Routing table verification")
        all_passed &= success

        return all_passed

    def check_internet_connectivity(self):
        self.print_section("Internet Connectivity")
        all_passed = True
        
        # DNS resolution test
        test_domains = ['google.com', 'microsoft.com', 'cloudflare.com']
        for domain in test_domains:
            if self.colors.is_windows:
                cmd = f"nslookup {domain}"
            else:
                cmd = f"dig +short {domain}"
            success, _ = self.run_cmd(cmd, f"DNS resolution for {domain}")
            all_passed &= success

        # ICMP connectivity
        test_ips = ['8.8.8.8', '1.1.1.1']
        for ip in test_ips:
            if self.colors.is_windows:
                cmd = f"ping -n 1 -w 2000 {ip}"
            else:
                cmd = f"ping -c 1 -W 2 {ip}"
            success, _ = self.run_cmd(cmd, f"ICMP connectivity to {ip}")
            all_passed &= success

        # HTTP connectivity
        test_urls = ['http://www.google.com', 'http://www.cloudflare.com']
        for url in test_urls:
            if self.colors.is_windows:
                cmd = f"powershell -Command \"Invoke-WebRequest -Uri {url} -UseBasicParsing -TimeoutSec 5\""
            else:
                cmd = f"curl -s --head --max-time 5 {url}"
            success, _ = self.run_cmd(cmd, f"HTTP connectivity to {url}")
            all_passed &= success

        return all_passed

    def verify_network(self):
        self.print_section(f"Network Verification - {self.role.upper()} ({self.own_ip})")
        
        checks = {
            "Required Packages": self.check_required_packages(),
            "Interface Configuration": self.verify_interface(),
            "VM Connectivity": self.test_connectivity(),
            "Internet Access": self.check_internet_connectivity()
        }
        
        self.print_section("Verification Summary")
        all_passed = all(checks.values())
        
        for check, status in checks.items():
            self.print_status(check, status)
        
        if not all_passed:
            print(f"\n{self.colors.YELLOW}Troubleshooting Tips:{self.colors.RESET}")
            print("1. Verify VirtualBox network settings")
            print("2. Check IP configurations")
            print("3. Verify gateway configuration")
            print("4. Check firewall settings")
            print("5. Verify required packages are installed")
        
        return all_passed

def main():
    try:
        # Skip root check on Windows
        if not sys.platform.startswith('win') and os.geteuid() != 0:
            print("Please run as administrator/root")
            sys.exit(1)
            
        verifier = NetworkVerification()
        if verifier.verify_network():
            print(f"\nAll checks passed!")
            sys.exit(0)
        else:
            print(f"\nSome checks failed!")
            sys.exit(1)
    except KeyboardInterrupt:
        print("\nTest interrupted by user")
        sys.exit(1)
    except Exception as e:
        print(f"\nError during testing: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()