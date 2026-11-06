#!/usr/bin/python3

import os
import sys
import subprocess
from pathlib import Path
import shutil

# Colors for output
RED = '\033[91m'
GREEN = '\033[92m'
YELLOW = '\033[93m'
NC = '\033[0m'

def check_root():
    if os.geteuid() != 0:
        print(f"{RED}[!] Please run as root{NC}")
        sys.exit(1)

def setup_apache():
    print(f"{YELLOW}[*] Setting up Apache...{NC}")
    
    # Install Apache if not present
    subprocess.run(["apt-get", "update"], check=True)
    subprocess.run(["apt-get", "install", "-y", "apache2"], check=True)
    
    # Enable required modules
    subprocess.run(["a2enmod", "rewrite"], check=True)
    subprocess.run(["a2enmod", "headers"], check=True)

def create_website():
    print(f"{YELLOW}[*] Creating fake banking website...{NC}")
    
    web_root = Path("/var/www/html")
    
    # Create HTML content
    html_content = """
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>Secure Banking Portal</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            margin: 0;
            padding: 20px;
            background-color: #f0f0f0;
        }
        .container {
            max-width: 800px;
            margin: 0 auto;
            background-color: white;
            padding: 20px;
            border-radius: 5px;
            box-shadow: 0 0 10px rgba(0,0,0,0.1);
        }
        .warning {
            background-color: #ff4444;
            color: white;
            padding: 10px;
            margin: 20px 0;
            border-radius: 5px;
        }
        .header {
            text-align: center;
            margin-bottom: 20px;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🏦 Secure Banking Portal</h1>
        </div>
        <div class="warning">
            <h2>⚠️ Security Alert!</h2>
            <p>Your traffic has been successfully redirected through an ICMP redirect attack.</p>
            <p>This is a demonstration of a security vulnerability.</p>
        </div>
        <div>
            <h3>Technical Details:</h3>
            <ul>
                <li>Original Destination: <span id="orig-dest"></span></li>
                <li>Redirected Through: <span id="redirect-ip"></span></li>
                <li>Current Server: <span id="current-server"></span></li>
            </ul>
        </div>
    </div>
    <script>
        // Add some dynamic content
        document.getElementById('current-server').textContent = window.location.host;
        document.getElementById('orig-dest').textContent = '192.168.201.1';
        document.getElementById('redirect-ip').textContent = '192.168.201.20';
    </script>
</body>
</html>
"""

    # Write HTML file
    with open(web_root / "index.html", "w") as f:
        f.write(html_content)

def configure_apache():
    print(f"{YELLOW}[*] Configuring Apache...{NC}")
    
    # Create Apache configuration
    config_content = """
<VirtualHost *:80>
    ServerAdmin webmaster@localhost
    DocumentRoot /var/www/html
    
    # Only allow access from local network
    <Directory /var/www/html>
        Options -Indexes +FollowSymLinks
        AllowOverride All
        Require ip 192.168.201.0/24
    </Directory>
    
    # Custom logging
    ErrorLog ${APACHE_LOG_DIR}/attack-error.log
    CustomLog ${APACHE_LOG_DIR}/attack-access.log combined
    
    # Security headers
    Header set X-Content-Type-Options "nosniff"
    Header set X-Frame-Options "DENY"
    Header set X-XSS-Protection "1; mode=block"
</VirtualHost>
"""
    
    # Write Apache config
    with open("/etc/apache2/sites-available/000-default.conf", "w") as f:
        f.write(config_content)

def setup_firewall():
    print(f"{YELLOW}[*] Configuring firewall rules...{NC}")
    
    # Allow only local network access
    subprocess.run(["iptables", "-A", "INPUT", "-p", "tcp", "--dport", "80", "-s", "192.168.201.0/24", "-j", "ACCEPT"])
    subprocess.run(["iptables", "-A", "INPUT", "-p", "tcp", "--dport", "80", "-j", "DROP"])

def backup_apache_config():
    """Backup Apache configuration"""
    print(f"{YELLOW}[*] Backing up Apache configuration...{NC}")
    
    config_file = "/etc/apache2/sites-available/000-default.conf"
    backup_file = f"{config_file}.backup"
    
    if not os.path.exists(backup_file):
        try:
            shutil.copy2(config_file, backup_file)
            print(f"{GREEN}[+] Apache config backed up to {backup_file}{NC}")
        except Exception as e:
            print(f"{RED}[!] Failed to backup Apache config: {e}{NC}")
            sys.exit(1)

def verify_setup():
    """Verify the setup was successful"""
    print(f"{YELLOW}[*] Verifying setup...{NC}")
    
    checks = [
        ("Apache service", "systemctl is-active apache2"),
        ("Website accessibility", f"curl -s -I http://localhost | grep '200 OK'"),
        ("Network accessibility", f"curl -s -I http://192.168.201.20 | grep '200 OK'"),
    ]
    
    all_passed = True
    for check_name, command in checks:
        try:
            result = subprocess.run(command, shell=True, capture_output=True, text=True)
            if result.returncode == 0:
                print(f"{GREEN}[+] {check_name}: OK{NC}")
            else:
                print(f"{RED}[-] {check_name}: Failed{NC}")
                all_passed = False
        except Exception as e:
            print(f"{RED}[-] {check_name}: Error - {e}{NC}")
            all_passed = False
    
    return all_passed

def main():
    try:
        check_root()
        print(f"{YELLOW}[*] Starting fake website setup...{NC}")
        
        backup_apache_config()
        setup_apache()
        create_website()
        configure_apache()
        setup_firewall()
        
        # Restart Apache
        subprocess.run(["systemctl", "restart", "apache2"], check=True)
        
        if verify_setup():
            print(f"\n{GREEN}[+] Fake website setup complete!{NC}")
            print(f"{YELLOW}[*] Website accessible at: http://192.168.201.20{NC}")
            print(f"{YELLOW}[*] Only accessible from 192.168.201.0/24{NC}")
        else:
            print(f"\n{RED}[!] Setup verification failed!{NC}")
            print(f"{YELLOW}[*] Please check the errors above{NC}")
            sys.exit(1)
        
    except subprocess.CalledProcessError as e:
        print(f"{RED}[!] Error executing command: {e}{NC}")
        sys.exit(1)
    except Exception as e:
        print(f"{RED}[!] Error: {e}{NC}")
        sys.exit(1)

if __name__ == "__main__":
    main()