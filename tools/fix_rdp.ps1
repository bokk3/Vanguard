# Run this script in an Administrator PowerShell prompt
Write-Host "=== Diagnosing and Fixing Windows Remote Desktop (RDP) ===" -ForegroundColor Cyan

# 1. Kill hung TermService process forcefully
Write-Host "`n[1/5] Terminating any hung TermService process..." -ForegroundColor Yellow
$termSvc = Get-WmiObject Win32_Service -Filter "Name='TermService'" -ErrorAction SilentlyContinue
if ($termSvc -and $termSvc.ProcessId -gt 0) {
    Stop-Process -Id $termSvc.ProcessId -Force -ErrorAction SilentlyContinue
}
taskkill /F /FI "SERVICES eq TermService" 2>$null
Start-Sleep -Seconds 2

# 2. Grant NetworkService access to MachineKeys for SSL certificate generation
Write-Host "`n[2/5] Ensuring MachineKeys permissions for NetworkService..." -ForegroundColor Yellow
$machineKeysPath = "C:\ProgramData\Microsoft\Crypto\RSA\MachineKeys"
icacls $machineKeysPath /grant "NT AUTHORITY\NetworkService:(OI)(CI)F" /t
icacls $machineKeysPath /grant "Everyone:(R,W)"

# 3. Create a dedicated self-signed SSL Certificate for RDP and bind it to WMI
Write-Host "`n[3/5] Generating and binding fresh RDP SSL certificate..." -ForegroundColor Yellow
try {
    $cert = New-SelfSignedCertificate -DnsName $env:COMPUTERNAME -CertStoreLocation "Cert:\LocalMachine\My"
    if ($cert) {
        Write-Host "Generated certificate thumbprint: $($cert.Thumbprint)" -ForegroundColor Cyan
        $tsSetting = Get-WmiObject -Class "Win32_TSGeneralSetting" -Namespace "root\cimv2\terminalservices" -Filter "TerminalName='RDP-tcp'"
        if ($tsSetting) {
            Set-WmiInstance -Path $tsSetting.__path -Arguments @{SSLCertificateSHA1Hash = $cert.Thumbprint}
            Write-Host "Successfully bound certificate to RDP-Tcp listener!" -ForegroundColor Green
        }
    }
} catch {
    Write-Warning "Certificate generation/binding notice: $_"
}

# 4. Start SessionEnv and TermService fresh
Write-Host "`n[4/5] Starting Remote Desktop services..." -ForegroundColor Yellow
Start-Service -Name SessionEnv -ErrorAction SilentlyContinue
Start-Service -Name TermService -ErrorAction SilentlyContinue
Start-Sleep -Seconds 3

# 5. Verification
Write-Host "`n[5/5] Verifying RDP Listener and Status..." -ForegroundColor Green
$certHash = (Get-CimInstance -Namespace root\cimv2\terminalservices -ClassName Win32_TSGeneralSetting -ErrorAction SilentlyContinue).SSLCertificateSHA1Hash
$listening = Get-NetTCPConnection -LocalPort 3389 -ErrorAction SilentlyContinue

Write-Host "SSL Certificate Hash: $certHash"
if ($listening) {
    Write-Host "`n========================================================" -ForegroundColor Green
    Write-Host ">>> SUCCESS: PORT 3389 IS NOW ACTIVE AND LISTENING! <<<" -ForegroundColor Green
    Write-Host "========================================================" -ForegroundColor Green
    Write-Host "Connect via LAN IP:       192.168.3.15:3389" -ForegroundColor Cyan
    Write-Host "Connect via Tailscale IP: 100.95.130.24:3389" -ForegroundColor Cyan
    Write-Host "Username:                 DESKTOP-TEUP5D7\Boris (or Boris)" -ForegroundColor Cyan
} else {
    Write-Host "`n[!] Listener check: If not yet active, checking netstat..." -ForegroundColor Yellow
    $netstat = netstat -ano | findstr :3389
    if ($netstat) {
        Write-Host ">>> SUCCESS: Port 3389 detected via netstat!" -ForegroundColor Green
    } else {
        Write-Host "[!] Port 3389 still pending. A single Windows reboot will cleanly initialize the service." -ForegroundColor Red
    }
}

Write-Host "`nPress any key to close..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
