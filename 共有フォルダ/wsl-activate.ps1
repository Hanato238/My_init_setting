# WSLを有効化するPowerShellスクリプト

# 管理者権限で実行されていることを確認
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "Process as Administrator"
    exit
}

# 既存のWSLのバージョンを確認
$wslVersion = Get-ItemPropertyValue -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WSMAN\Client" -Name "DefaultPorts" -ErrorAction SilentlyContinue

if ($wslVersion -eq $null) {
    Write-Host "WSL is not activated"
} else {
    Write-Host "WSL has already been activated"
    exit
}


# WSLを有効化する
Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux

# 再起動を促すメッセージ
Write-Host "Activated WSL, a part of function start working after restart"
Write-Host "コンピューターを再起動しますか？ (y/n)"
$choice = Read-Host

if ($choice -eq "y" -or $choice -eq "Y") {
    Restart-Computer
} else {
    Write-Host "再起動するまで一部の変更が有効にならない可能性があります。手動で再起動してください"
}