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
.PARAMETER Mode
    On  : 24時間サーバー化設定を有効化（既定値）
    Off : 24時間サーバー化設定を解除し、通常のPC向け設定に戻す
.PARAMETER DryRun
    実際には変更せず、実行内容を確認するだけのモード
.NOTES
    管理者権限で実行してください
    例: Right-click → "管理者として実行"
    例: .\Set-ServerMode.ps1 -Mode On
    例: .\Set-ServerMode.ps1 -Mode Off
    例: .\Set-ServerMode.ps1 Off -DryRun
#>

param(
    [Parameter(Position = 0)]
    [ValidateSet("On", "Off")]
    [string]$Mode = "On",

    [switch]$DryRun
)

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
Write-Host " Windows 24時間サーバー化設定スクリプト (Mode: $Mode)" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# ------------------------------------------------------------
# 1. スリープ・休止状態・モニターの無効化 / 復元
# ------------------------------------------------------------
if ($Mode -eq "On") {
    Write-Host "[1/6] スリープ・休止状態を無効化中..." -ForegroundColor Yellow

    Invoke-Step "スリープ無効化 (AC)" { powercfg /change standby-timeout-ac 0 }
    Invoke-Step "スリープ無効化 (DC)" { powercfg /change standby-timeout-dc 0 }
    Invoke-Step "休止状態タイムアウト無効化 (AC)" { powercfg /change hibernate-timeout-ac 0 }
    Invoke-Step "休止状態タイムアウト無効化 (DC)" { powercfg /change hibernate-timeout-dc 0 }
    Invoke-Step "モニタータイムアウト無効化 (AC)" { powercfg /change monitor-timeout-ac 0 }
    Invoke-Step "休止状態機能を無効化" { powercfg /hibernate off }
} else {
    Write-Host "[1/6] スリープ・休止状態を通常設定に復元中..." -ForegroundColor Yellow

    Invoke-Step "休止状態機能を有効化" { powercfg /hibernate on }
    Invoke-Step "スリープ設定を復元 (AC: 30分)" { powercfg /change standby-timeout-ac 30 }
    Invoke-Step "スリープ設定を復元 (DC: 15分)" { powercfg /change standby-timeout-dc 15 }
    Invoke-Step "休止状態タイムアウトを復元 (AC: 180分)" { powercfg /change hibernate-timeout-ac 180 }
    Invoke-Step "休止状態タイムアウトを復元 (DC: 180分)" { powercfg /change hibernate-timeout-dc 180 }
    Invoke-Step "モニタータイムアウトを復元 (AC: 10分)" { powercfg /change monitor-timeout-ac 10 }
}

Write-Host ""

# ------------------------------------------------------------
# 2. ノートPC: 蓋を閉じてもスリープしない設定 / 復元
# ------------------------------------------------------------
# SUB_BUTTONS  GUID: 4f971e89-eebd-4455-a8de-9e59040e7347
# LIDACTION    GUID: 5ca83367-6e45-459f-a27b-476b1d01c936
# 0 = 何もしない, 1 = スリープ (既定)
if ($Mode -eq "On") {
    Write-Host "[2/6] ノートPC蓋閉じ時のスリープを無効化中..." -ForegroundColor Yellow

    Invoke-Step "蓋閉じ → 何もしない (AC)" {
        powercfg /SETACVALUEINDEX SCHEME_CURRENT 4f971e89-eebd-4455-a8de-9e59040e7347 5ca83367-6e45-459f-a27b-476b1d01c936 0
    }
    Invoke-Step "蓋閉じ → 何もしない (DC)" {
        powercfg /SETDCVALUEINDEX SCHEME_CURRENT 4f971e89-eebd-4455-a8de-9e59040e7347 5ca83367-6e45-459f-a27b-476b1d01c936 0
    }
} else {
    Write-Host "[2/6] ノートPC蓋閉じ時のスリープ設定を復元中..." -ForegroundColor Yellow

    Invoke-Step "蓋閉じ → スリープ (AC)" {
        powercfg /SETACVALUEINDEX SCHEME_CURRENT 4f971e89-eebd-4455-a8de-9e59040e7347 5ca83367-6e45-459f-a27b-476b1d01c936 1
    }
    Invoke-Step "蓋閉じ → スリープ (DC)" {
        powercfg /SETDCVALUEINDEX SCHEME_CURRENT 4f971e89-eebd-4455-a8de-9e59040e7347 5ca83367-6e45-459f-a27b-476b1d01c936 1
    }
}
Invoke-Step "現在のプランに適用" { powercfg /SETACTIVE SCHEME_CURRENT }

Write-Host ""

# ------------------------------------------------------------
# 3. 電源プランの変更
# ------------------------------------------------------------
if ($Mode -eq "On") {
    Write-Host "[3/6] 高パフォーマンス電源プランを設定中..." -ForegroundColor Yellow

    Invoke-Step "高パフォーマンスプランを有効化" {
        powercfg /setactive 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c
    }
} else {
    Write-Host "[3/6] 電源プランをバランスに戻し中..." -ForegroundColor Yellow

    Invoke-Step "バランスプランを有効化" {
        powercfg /setactive 381b4222-f694-41f0-9685-ff5bb260df2e
    }
}

Write-Host ""

# ------------------------------------------------------------
# 4. 自動ログイン設定（オプション）
# ------------------------------------------------------------
Write-Host "[4/6] 自動ログイン設定..." -ForegroundColor Yellow

if ($Mode -eq "On") {
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
} else {
    Invoke-Step "自動ログイン無効化" {
        $regPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon"
        Set-ItemProperty $regPath "AutoAdminLogon" -Value "0"
        Remove-ItemProperty $regPath "DefaultPassword" -ErrorAction SilentlyContinue
    }
}

Write-Host ""

# ------------------------------------------------------------
# 5. Windows Update の無効化 / 有効化
# ------------------------------------------------------------
if ($Mode -eq "On") {
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
} else {
    Write-Host "[5/6] Windows Update を有効化中..." -ForegroundColor Yellow

    Invoke-Step "グループポリシーの自動更新無効化設定を解除" {
        $auPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU"
        if (Test-Path $auPath) { Remove-Item -Path $auPath -Recurse -Force }
    }
    Invoke-Step "Windows Update サービス (wuauserv) を有効化" {
        Set-Service  -Name wuauserv -StartupType Manual
        Start-Service -Name wuauserv -ErrorAction SilentlyContinue
    }
    Invoke-Step "Update Orchestrator サービス (UsoSvc) を有効化" {
        Set-Service  -Name UsoSvc -StartupType Manual
        Start-Service -Name UsoSvc -ErrorAction SilentlyContinue
    }
    Invoke-Step "Windows Update スケジュールタスクを有効化" {
        $tasks = @(
            "\Microsoft\Windows\WindowsUpdate\Scheduled Start"
            "\Microsoft\Windows\UpdateOrchestrator\Schedule Scan"
            "\Microsoft\Windows\UpdateOrchestrator\USO_UxBroker"
        )
        foreach ($t in $tasks) {
            Enable-ScheduledTask -TaskPath (Split-Path $t) -TaskName (Split-Path $t -Leaf) -ErrorAction SilentlyContinue
        }
    }
}

Write-Host ""

# ------------------------------------------------------------
# 6. OpenSSH Server & Tailscale 自動起動設定
# ------------------------------------------------------------
if ($Mode -eq "On") {
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
} else {
    Write-Host "[6/6] サービス自動起動を解除中..." -ForegroundColor Yellow

    # OpenSSH Server
    $sshd = Get-Service -Name sshd -ErrorAction SilentlyContinue
    if ($sshd) {
        Invoke-Step "sshd: 手動起動に変更" { Set-Service -Name sshd -StartupType Manual }
        Invoke-Step "sshd: 停止" {
            if ((Get-Service -Name sshd).Status -eq "Running") { Stop-Service sshd -Force }
        }
        Invoke-Step "ファイアウォール: TCP 22 の許可ルールを削除" {
            Remove-NetFirewallRule -Name "OpenSSH-Server-In-TCP" -ErrorAction SilentlyContinue
        }
    } else {
        Write-Host "  sshd: 未インストールのためスキップ" -ForegroundColor DarkGray
    }

    # Tailscale
    $tailscale = Get-Service -Name Tailscale -ErrorAction SilentlyContinue
    if ($tailscale) {
        Invoke-Step "Tailscale: 手動起動に変更" { Set-Service -Name Tailscale -StartupType Manual }
    } else {
        Write-Host "  Tailscale: サービスが見つかりません" -ForegroundColor DarkGray
    }
}

# ------------------------------------------------------------
# 完了サマリー
# ------------------------------------------------------------
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
if ($Mode -eq "On") {
    Write-Host " サーバー化設定 完了！現在の状態" -ForegroundColor Cyan
} else {
    Write-Host " サーバー化設定 解除完了！現在の状態" -ForegroundColor Cyan
}
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
