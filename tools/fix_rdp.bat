@echo off
:: Batch wrapper to elevate to Administrator automatically and run fix_rdp.ps1
>nul 2>&1 "%SYSTEMROOT%\system32\cacls.exe" "%SYSTEMROOT%\system32\config\system"
if '%errorlevel%' NEQ '0' (
    echo Requesting administrative privileges...
    powershell -Command "Start-Process '%~f0' -Verb runAs"
    exit /b
)

echo Running RDP repair script...
powershell -NoProfile -ExecutionPolicy Bypass -File "c:\Users\Boris\Documents\antigravity\lucid-davinci\tools\fix_rdp.ps1"
pause
