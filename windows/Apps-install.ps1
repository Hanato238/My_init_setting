# Chocolateyがインストールされているか確認
if (-not (Get-Command choco -ErrorAction SilentlyContinue)) {
    Write-Host "Chocolateyがインストールされていません。先にChocolateyをインストールしてください。"
    return
}

# Python 3.9から13までをインストール
choco install python python39 python310 pytnon311 -y
# VS Codeをインストール
choco install vscode -y
# Ubuntuをインストール
choco install wsl-ubuntu-2204 -y
# docker desktopをインストール
choco install docker-desktop -y



# OneDriveをインストール
choco install onedrive -y
# zoomをインストール
choco install zoom -y
# LINEをインストール
choco install line -y
# VMware workstationをインストール
choco install vmware-workstation-player -y
# kindleをインストール
choco install kindle -y




# Vimをインストール
choco install vim -y
# Curlをインストール
choco install curl -y
# Gitをインストール
choco install git gh -y
# ExpressVPNをインストール
choco install expressvpn -y
# vscode marterialiconをインストール
choco install materialicon-vscode -y
# powertoysをインストール
choco install powertoys -y


# すべてのアプリをupgrade
chogo upgrade all -y


# Set $PROFILE
$profilePath = $PROFILE
if (-not (Test-Path -Path $profilePath -PathType Leaf)) {
    New-Item -Path $profilePath -ItemType File
}

Add-Content -Path $profilePath -Value @"
function su { Start-Process powershell -Verb runas }
Set-Alias -Name "chrome" -Value "C:\Program Files\Google\Chrome\Application\chrome.exe"
Set-Alias -Name "chatgpt" -Value "C:\Program Files\Google\Chrome\Application\chrome.exe https://chat.openai.com/"
Set-Alias -Name "line" -Value "C:\Users\lesen\AppData\Local\LINE\bin\LineLauncher.exe"
Set-Alias -Name "vscode" -Value "C:\Program Files\Microsoft VS Code\Code.exe"
Set-Alias -Name "expressvpn" -Value "C:\Program Files (x86)\ExpressVPN\expressvpn-ui\ExpressVPN.exe"
Set-Alias -Name "kindle" -Value "C:\Program Files (x86)\Amazon\Kindle\Kindle.exe"
Set-Alias -Name "docker-desktop" -Value "C:\Program Files\Docker\Docker\Docker Desktop.exe"

$workspace = "C:\Users\lesen\workspace"
"@
