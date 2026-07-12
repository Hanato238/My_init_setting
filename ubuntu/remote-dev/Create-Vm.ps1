<#
.SYNOPSIS
    GCP上にリモート開発用Ubuntu VMを作成する
.DESCRIPTION
    config/vm-config.json の設定を使って `gcloud compute instances create` を実行する。
    startup-script.sh を起動スクリプトとして添付するため、VM起動後は自動的に
    ubuntu/remote-dev/setup.sh が実行され、Tailscale（tailscaled起動・IP forwarding）
    と Orca headless server（orca-serve.service）のセットアップが完了する。
    -TailscaleAuthKey を指定した場合はTailscale認証も非対話で完了する。
    未指定の場合はTailscale認証のみ手動（SSHで入って `sudo tailscale up ...`）が必要。
    Exit node承認（Tailscale管理コンソール）とOrcaクライアントのペアリングは
    どちらの場合も引き続き手動。
.PARAMETER ConfigPath
    VM設定JSONファイルのパス（既定: config/vm-config.json）
.PARAMETER TailscaleAuthKey
    Tailscale の auth key。指定するとVM起動時にTailscale認証も自動化される
    （インスタンスメタデータ経由でVMに渡すため、リポジトリにはコミットしないこと）。
    未指定時は $env:TAILSCALE_AUTHKEY を使用する。
.PARAMETER DryRun
    実際にはVMを作成せず、実行される gcloud コマンドを表示するだけのモード
.NOTES
    事前に gcloud SDK のインストールと `gcloud auth login` が必要。
#>

param(
    [string]$ConfigPath = "$PSScriptRoot\config\vm-config.json",
    [string]$TailscaleAuthKey = $env:TAILSCALE_AUTHKEY,
    [switch]$DryRun
)

if (-not (Test-Path $ConfigPath)) {
    Write-Error "Config file not found: $ConfigPath"
    exit 1
}

$config = Get-Content $ConfigPath -Raw | ConvertFrom-Json

foreach ($required in @('projectId', 'zone', 'vmName', 'machineType', 'imageFamily', 'imageProject')) {
    if (-not $config.$required) {
        Write-Error "Missing required config field '$required' in $ConfigPath"
        exit 1
    }
}

if ($config.projectId -eq 'your-gcp-project-id') {
    Write-Error "config/vm-config.json still has the placeholder projectId. Edit it with your real GCP project ID first."
    exit 1
}

if (-not (Get-Command gcloud -ErrorAction SilentlyContinue)) {
    Write-Error "gcloud CLI not found. Install it first (e.g. choco install gcloudsdk), then run: gcloud init"
    exit 1
}

$activeAccount = (gcloud auth list --filter="status:ACTIVE" --format="value(account)" 2>$null)
if (-not $activeAccount) {
    Write-Error "No active gcloud account. Run: gcloud auth login"
    exit 1
}
Write-Host "gcloud account: $activeAccount" -ForegroundColor Cyan

$diskSizeGb = if ($config.diskSizeGb) { $config.diskSizeGb } else { 30 }
$diskType   = if ($config.diskType)   { $config.diskType }   else { "pd-balanced" }

$gcloudArgs = @(
    "compute", "instances", "create", $config.vmName,
    "--project=$($config.projectId)",
    "--zone=$($config.zone)",
    "--machine-type=$($config.machineType)",
    "--image-family=$($config.imageFamily)",
    "--image-project=$($config.imageProject)",
    "--boot-disk-size=${diskSizeGb}GB",
    "--boot-disk-type=$diskType"
)

if ($config.enableIpForward) {
    # exit node化に必要。既存インスタンスには後から設定できない（作成時のみ）
    $gcloudArgs += "--can-ip-forward"
}

if ($config.networkTags -and $config.networkTags.Count -gt 0) {
    $gcloudArgs += "--tags=$($config.networkTags -join ',')"
}

$startupScriptPath = "$PSScriptRoot\startup-script.sh"
if (-not (Test-Path $startupScriptPath)) {
    Write-Error "startup-script.sh not found: $startupScriptPath"
    exit 1
}
$gcloudArgs += "--metadata-from-file=startup-script=$startupScriptPath"
if ($TailscaleAuthKey) {
    $gcloudArgs += "--metadata=tailscale-authkey=$TailscaleAuthKey"
}

Write-Host "`n=== gcloud command ===" -ForegroundColor Cyan
$printableArgs = $gcloudArgs | ForEach-Object {
    if ($_ -like '--metadata=tailscale-authkey=*') { '--metadata=tailscale-authkey=***' } else { $_ }
}
Write-Host "gcloud $($printableArgs -join ' ')"

if ($DryRun) {
    Write-Host "`n[DRY RUN] VM was not created." -ForegroundColor Yellow
    exit 0
}

Write-Host "`nCreating VM '$($config.vmName)'..." -ForegroundColor Cyan
& gcloud @gcloudArgs
if ($LASTEXITCODE -ne 0) {
    Write-Error "gcloud compute instances create failed (exit code $LASTEXITCODE)."
    exit $LASTEXITCODE
}

Write-Host "`n=== VM created ===" -ForegroundColor Green
Write-Host "The startup script bootstraps Tailscale + Orca automatically on first boot"
Write-Host "(usually takes 1-2 minutes). SSH in to check progress:"
Write-Host "  gcloud compute ssh $($config.vmName) --zone=$($config.zone) --project=$($config.projectId)"
Write-Host "  sudo journalctl -u google-startup-scripts -f"
Write-Host ""
if ($TailscaleAuthKey) {
    Write-Host "-TailscaleAuthKey was supplied, so Tailscale auth is automated too." -ForegroundColor Green
} else {
    Write-Host "No -TailscaleAuthKey supplied, so Tailscale auth is NOT automated." -ForegroundColor Yellow
    Write-Host "After SSH-ing in, authenticate manually:"
    Write-Host "  sudo tailscale up --ssh --advertise-exit-node"
}
Write-Host ""
Write-Host "Remaining manual steps (either way):"
Write-Host "  1. If this VM should be a Tailscale exit node, approve it in the"
Write-Host "     Tailscale admin console."
Write-Host "  2. Pair an external Orca client (desktop/mobile) using the pairing URL:"
Write-Host "       sudo journalctl -u orca-serve -f"
