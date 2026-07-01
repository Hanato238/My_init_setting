#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Windows 24時間サーバー化設定スクリプト
.DESCRIPTION
    - スリープ・休止状態の無効化
    - ノートPC蓋閉じ時のスリープ無効化
    - 高パフォーマンス電源プラン設定
    - 自動ログイン設定（オプション）
    - Windows Update の無効化
    - OpenSSH Server 自動起動設定
    - Tailscale 自動起動設定
.PARAMETER DryRun
    実際には変更せず、実行内容を確認するだけのモード
.NOTES
    管理者権限で実行してください
    例: Right-click → "管理者として実行"
#>

param([switch]$DryRun)

Set-ExecutionPolicy Bypass -Scope Process -Force

# ============================================================
# ユーザー設定（必要に応じて変更してください）
# ============================================================
$AutoLoginEnabled  = $false    # 自動ログインを有効にする場合は $true
$AutoLoginUsername = "lesen"   # 自動ログインのユーザー名
$AutoLoginPassword = ""        # 自動ログインのパスワード（平文注意）
# ============================================================

function Invoke-Step([string]$Label, [scriptblock]$Action) {
    Write-Host "  $Label" -NoNewline
    if ($DryRun) {
        Write-Host " [DRY RUN]" -ForegroundColor Yellow
        return
    }
    try {
        & $Action
        Write-Host " -> 完了" -ForegroundColor Green
    } catch {
        Write-Host " -> 失敗: $_" -ForegroundColor Red
    }
}

Write-Host "========================================" -ForegroundColor Cyan
Write-Host " Windows 24時間サーバー化設定スクリプト" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# ------------------------------------------------------------
# 1. スリープ・休止状態・モニターの無効化
# ------------------------------------------------------------
Write-Host "[1/6] スリープ・休止状態を無効化中..." -ForegroundColor Yellow

Invoke-Step "スリープ無効化 (AC)" { powercfg /change standby-timeout-ac 0 }
Invoke-Step "スリープ無効化 (DC)" { powercfg /change standby-timeout-dc 0 }
Invoke-Step "休止状態タイムアウト無効化 (AC)" { powercfg /change hibernate-timeout-ac 0 }
Invoke-Step "休止状態タイムアウト無効化 (DC)" { powercfg /change hibernate-timeout-dc 0 }
Invoke-Step "モニタータイムアウト無効化 (AC)" { powercfg /change monitor-timeout-ac 0 }
Invoke-Step "休止状態機能を無効化" { powercfg /hibernate off }

Write-Host ""

# ------------------------------------------------------------
# 2. ノートPC: 蓋を閉じてもスリープしない設定
# ------------------------------------------------------------
Write-Host "[2/6] ノートPC蓋閉じ時のスリープを無効化中..." -ForegroundColor Yellow

# SUB_BUTTONS  GUID: 4f971e89-eebd-4455-a8de-9e59040e7347
# LIDACTION    GUID: 5ca83367-6e45-459f-a27b-476b1d01c936
# 0 = 何もしない
Invoke-Step "蓋閉じ → 何もしない (AC)" {
    powercfg /SETACVALUEINDEX SCHEME_CURRENT 4f971e89-eebd-4455-a8de-9e59040e7347 5ca83367-6e45-459f-a27b-476b1d01c936 0
}
Invoke-Step "蓋閉じ → 何もしない (DC)" {
    powercfg /SETDCVALUEINDEX SCHEME_CURRENT 4f971e89-eebd-4455-a8de-9e59040e7347 5ca83367-6e45-459f-a27b-476b1d01c936 0
}
Invoke-Step "現在のプランに適用" { powercfg /SETACTIVE SCHEME_CURRENT }

Write-Host ""

# ------------------------------------------------------------
# 3. 高パフォーマンス電源プランに変更
# ------------------------------------------------------------
Write-Host "[3/6] 高パフォーマンス電源プランを設定中..." -ForegroundColor Yellow

Invoke-Step "高パフォーマンスプランを有効化" {
    powercfg /setactive 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c
}

Write-Host ""

# ------------------------------------------------------------
# 4. 自動ログイン設定（オプション）
# ------------------------------------------------------------
Write-Host "[4/6] 自動ログイン設定..." -ForegroundColor Yellow

if ($AutoLoginEnabled -and $AutoLoginPassword -ne "") {
    Invoke-Step "自動ログイン有効化 (ユーザー: $AutoLoginUsername)" {
        $regPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon"
        Set-ItemProperty $regPath "AutoAdminLogon"  -Value "1"
        Set-ItemProperty $regPath "DefaultUsername" -Value $AutoLoginUsername
        Set-ItemProperty $regPath "DefaultPassword" -Value $AutoLoginPassword
    }
} else {
    Write-Host "  スキップ (有効にするには `$AutoLoginEnabled = `$true と `$AutoLoginPassword を設定)" -ForegroundColor DarkGray
}

Write-Host ""

# ------------------------------------------------------------
# 5. Windows Update の無効化
# ------------------------------------------------------------
Write-Host "[5/6] Windows Update を無効化中..." -ForegroundColor Yellow

Invoke-Step "グループポリシーで自動更新を無効化" {
    $auPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU"
    if (-not (Test-Path $auPath)) { New-Item -Path $auPath -Force | Out-Null }
    Set-ItemProperty $auPath "NoAutoUpdate"                 -Value 1 -Type DWord
    Set-ItemProperty $auPath "AUOptions"                    -Value 1 -Type DWord
    Set-ItemProperty $auPath "NoAutoRebootWithLoggedOnUsers" -Value 1 -Type DWord
}
Invoke-Step "Windows Update サービス (wuauserv) を無効化" {
    Stop-Service -Name wuauserv -Force -ErrorAction SilentlyContinue
    Set-Service  -Name wuauserv -StartupType Disabled
}
Invoke-Step "Update Orchestrator サービス (UsoSvc) を無効化" {
    Stop-Service -Name UsoSvc -Force -ErrorAction SilentlyContinue
    Set-Service  -Name UsoSvc -StartupType Disabled
}
Invoke-Step "Windows Update スケジュールタスクを無効化" {
    $tasks = @(
        "\Microsoft\Windows\WindowsUpdate\Scheduled Start"
        "\Microsoft\Windows\UpdateOrchestrator\Schedule Scan"
        "\Microsoft\Windows\UpdateOrchestrator\USO_UxBroker"
    )
    foreach ($t in $tasks) {
        Disable-ScheduledTask -TaskPath (Split-Path $t) -TaskName (Split-Path $t -Leaf) -ErrorAction SilentlyContinue
    }
}

Write-Host ""

# ------------------------------------------------------------
# 6. OpenSSH Server & Tailscale 自動起動設定
# ------------------------------------------------------------
Write-Host "[6/6] サービス自動起動を設定中..." -ForegroundColor Yellow

# OpenSSH Server
$sshd = Get-Service -Name sshd -ErrorAction SilentlyContinue
if ($sshd) {
    Invoke-Step "sshd: 自動起動に設定" { Set-Service -Name sshd -StartupType Automatic }
    Invoke-Step "sshd: 起動" {
        if ((Get-Service -Name sshd).Status -ne "Running") { Start-Service sshd }
    }
    Invoke-Step "ファイアウォール: TCP 22 を許可" {
        if (-not (Get-NetFirewallRule -Name "OpenSSH-Server-In-TCP" -ErrorAction SilentlyContinue)) {
            New-NetFirewallRule -Name "OpenSSH-Server-In-TCP" `
                -DisplayName "OpenSSH Server (sshd)" `
                -Enabled True -Direction Inbound -Protocol TCP -Action Allow -LocalPort 22
        }
    }
} else {
    Write-Host "  sshd: 未インストール。以下のコマンドで別途インストールしてください:" -ForegroundColor Red
    Write-Host "    Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0" -ForegroundColor DarkGray
}

# Tailscale
$tailscale = Get-Service -Name Tailscale -ErrorAction SilentlyContinue
if ($tailscale) {
    Invoke-Step "Tailscale: 自動起動に設定" { Set-Service -Name Tailscale -StartupType Automatic }
} else {
    Write-Host "  Tailscale: サービスが見つかりません（インストール後に再実行してください）" -ForegroundColor DarkGray
}

# ------------------------------------------------------------
# 完了サマリー
# ------------------------------------------------------------
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host " 設定完了！現在の状態" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

Write-Host ""
Write-Host "【電源プラン】"
powercfg /getactivescheme

Write-Host ""
Write-Host "【サービス状態】"
$serviceNames = @("sshd", "Tailscale") | Where-Object { Get-Service -Name $_ -ErrorAction SilentlyContinue }
if ($serviceNames) {
    Get-Service $serviceNames -ErrorAction SilentlyContinue |
        Format-Table Name, Status, StartType -AutoSize
}

Write-Host ""
Write-Host "【Tailscale 接続状態】"
tailscale status 2>$null

Write-Host ""
Write-Host "再起動後も設定が有効であることを確認するため、一度再起動をお勧めします。" -ForegroundColor Yellow
