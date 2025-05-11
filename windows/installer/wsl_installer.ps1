Set-ExecutionPolicy Bypass -Scope Process -Force

# check if Chocolatey is installed
if (-not (Get-Command choco -ErrorAction SilentlyContinue)) {
    Write-Host "Chocolatey is not installed. Please install Chocolatey first." -ForegroundColor Red
    return
}

# install WSL2
choco install wsl2 -y

# check if WSL is already activated
$wslVersion = Get-ItemPropertyValue -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WSMAN\Client" -Name "DefaultPorts" -ErrorAction SilentlyContinue

if ($wslVersion -eq $null) {
    Write-Host "WSL is not activated"
} else {
    Write-Host "WSL has already been activated"
    exit
}


# activate WSL
Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux

# check if WSL is activated
Write-Host "Activated WSL, a part of function start working after restart"
Write-Host "Do you want to restart your computer now? (y/n)"
$choice = Read-Host

if ($choice -eq "y" -or $choice -eq "Y") {
    Restart-Computer
} else {
    Write-Host "if you want to restart, please restart manually"
    Write-Host "Please restart your computer to apply the changes." -ForegroundColor Yellow
}