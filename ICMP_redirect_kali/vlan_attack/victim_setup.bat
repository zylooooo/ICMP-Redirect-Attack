@echo off
:: victim_setup.bat
echo [*] Setting up Windows Victim Machine Network...

:: Set static IP
echo [*] Configuring network settings...
netsh interface ip set address "Ethernet" static 192.168.201.10 255.255.255.0 192.168.201.2

:: Configure DNS
echo [*] Setting up DNS...
netsh interface ip set dns "Ethernet" static 8.8.8.8
netsh interface ip add dns "Ethernet" 8.8.4.4 index=2

:: Configure Windows Firewall for ICMP
echo [*] Configuring firewall...
netsh advfirewall firewall delete rule name="Allow ICMP" protocol=icmpv4
netsh advfirewall firewall delete rule name="Allow ICMP out" protocol=icmpv4
netsh advfirewall firewall add rule name="Allow ICMP" protocol=icmpv4:any,any dir=in action=allow
netsh advfirewall firewall add rule name="Allow ICMP out" protocol=icmpv4:any,any dir=out action=allow

:: Display configuration
echo.
echo [+] Current Network Configuration:
ipconfig /all

:: Test connectivity
echo.
echo [*] Testing connectivity...
ping 192.168.201.1
ping 8.8.8.8

echo.
echo [+] Network setup complete! Press any key to exit...
pause > nul