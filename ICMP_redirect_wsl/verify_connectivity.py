#!/usr/bin/python3
import subprocess
import time
import sys
import os

def run_cmd(cmd, description="", verbose=True):
    """Execute command and return result with proper formatting"""
    if verbose:
        print(f"\n[TEST] {description}" if description else f"\nExecuting: {cmd}")
    result = subprocess.run(cmd, shell=True, text=True, capture_output=True)
    if result.returncode == 0:
        if verbose:
            print(f"✅ Success: {result.stdout.strip()}")
        return True, result.stdout
    else:
        if verbose:
            print(f"❌ Failed: {result.stderr.strip()}")
        return False, result.stderr
    
def check_wsl_environment():
    """Verify WSL-specific requirements"""
    print("\n=== Checking WSL Environment ===")
    
    # Check if running in WSL
    is_wsl = os.path.exists('/proc/sys/fs/binfmt_misc/WSLInterop')
    print(f"Running in WSL: {'✅' if is_wsl else '❌'}")
    
    # Check WSL network interface
    success, output = run_cmd("ip route | grep default | awk '{print $5}'", verbose=False)
    if success:
        print(f"WSL Interface: ✅ ({output.strip()})")
    else:
        print("WSL Interface: ❌ (Not found)")

def test_namespace_connectivity(ns_name):
    """Test connectivity for a specific namespace"""
    print(f"\n=== Testing {ns_name} namespace connectivity ===")
    tests = [
        # Interface check with detailed output
        (f"ip netns exec {ns_name} ip addr show", "Interface configuration"),
        (f"ip netns exec {ns_name} ip link show", "Link status"),
        
        # Detailed route check
        (f"ip netns exec {ns_name} ip route show", "Routing table"),
        
        # Connectivity tests with increased timeout
        (f"timeout 5 ip netns exec {ns_name} ping -c 2 -W 2 192.168.1.1", "Ping to gateway"),
        (f"timeout 5 ip netns exec {ns_name} ping -c 2 -W 2 8.8.8.8", "Internet connectivity"),
        
        # DNS with explicit server
        (f"ip netns exec {ns_name} ping -c 1 -W 2 google.com", "DNS resolution")
    ]
    
    success = True
    for cmd, desc in tests:
        if not run_cmd(cmd, desc)[0]:
            success = False
            # Additional debugging for failed tests
            if "ping" in cmd:
                run_cmd(f"ip netns exec {ns_name} ip route get $(echo {cmd} | awk '{{print $NF}}')", 
                       f"Route to {desc} target")
    return success

def verify_network():
    """Comprehensive network verification"""
    print("🔍 Starting Network Verification\n")
    
    # Check WSL environment first
    check_wsl_environment()
    
    # Verify namespace existence and configuration
    print("\n=== Checking Network Namespaces ===")
    success, output = run_cmd("ip netns list", "Available network namespaces")
    if not success:
        print("❌ No network namespaces found. Please run wsl_setup.sh first.")
        return False

    # Test each namespace
    namespaces = ["victim", "attacker", "gateway"]
    namespace_status = {}
    
    for ns in namespaces:
        namespace_status[ns] = test_namespace_connectivity(ns)
        
        # Additional checks for each namespace
        run_cmd(f"ip netns exec {ns} sysctl net.ipv4.ip_forward", f"IP forwarding status ({ns})")
        if ns == "victim":
            run_cmd(f"ip netns exec {ns} sysctl net.ipv4.conf.all.accept_redirects", 
                   "ICMP redirects status (victim)")

    # Summary with detailed status
    print("\n=== Detailed Test Summary ===")
    all_passed = all(namespace_status.values())
    
    for ns, status in namespace_status.items():
        print(f"{ns}: {'✅ Passed' if status else '❌ Failed'}")
        if not status:
            print(f"  - Check {ns} namespace configuration in wsl_setup.sh")
    
    if not all_passed:
        print("\n⚠️ Troubleshooting Steps:")
        print("1. Run './thorough_cleanup.sh' to clean existing configuration")
        print("2. Re-run './wsl_setup.sh' to recreate the network setup")
        print("3. Verify ICMP redirect settings: 'sysctl net.ipv4.conf.all.accept_redirects'")
    
    return all_passed

if __name__ == "__main__":
    try:
        if verify_network():
            sys.exit(0)
        else:
            sys.exit(1)
    except KeyboardInterrupt:
        print("\n\nTest interrupted by user")
        sys.exit(1)
    except Exception as e:
        print(f"\n\nError during testing: {e}")
        sys.exit(1) 