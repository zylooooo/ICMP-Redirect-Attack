@echo off
:: toggle_icmp_redirect.bat
setlocal EnableDelayedExpansion

:: Check current ICMP redirect status
for /f "tokens=3" %%a in ('reg query "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" /v "EnableICMPRedirect" 2^>nul') do set "current=%%a"

if "%1"=="" (
    :: No argument provided, show menu
    echo Current ICMP Redirect Status: !current!
    echo.
    echo ICMP Redirect Control Menu:
    echo [1] Enable ICMP Redirects (Vulnerable)
    echo [2] Disable ICMP Redirects (Protected)
    echo [3] Show Current Status
    echo [4] Exit
    echo.
    set /p choice="Enter your choice (1-4): "
) else (
    :: Argument provided
    set choice=%1
)

if "!choice!"=="1" (
    echo [*] Enabling ICMP redirects (making system vulnerable)...
    reg add "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" /v "EnableICMPRedirect" /t REG_DWORD /d 1 /f
    echo [+] ICMP redirects enabled. System is now vulnerable to ICMP redirect attacks.
) else if "!choice!"=="2" (
    echo [*] Disabling ICMP redirects (protecting system)...
    reg add "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" /v "EnableICMPRedirect" /t REG_DWORD /d 0 /f
    echo [+] ICMP redirects disabled. System is now protected from ICMP redirect attacks.
) else if "!choice!"=="3" (
    echo.
    echo Current ICMP Redirect Settings:
    echo ----------------------------
    reg query "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" /v "EnableICMPRedirect"
    if "!current!"=="0x1" (
        echo Status: VULNERABLE to ICMP redirect attacks
    ) else (
        echo Status: PROTECTED from ICMP redirect attacks
    )
) else if "!choice!"=="4" (
    exit /b 0
) else if "!choice!" NEQ "" (
    echo [-] Invalid choice. Please select 1-4.
)

echo.
echo [*] Note: Changes will take effect after system restart.
pause
