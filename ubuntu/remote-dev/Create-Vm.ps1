<#
.SYNOPSIS
    GCP上にリモート開発用Ubuntu VMを作成する
.DESCRIPTION
    config/vm-config.json の設定を使って `gcloud compute instances create` を実行する。
    VM作成後は SSH で入り、ubuntu/setup.sh remote-dev を実行して Tailscale + Orca をセットアップする
    （そちらは別途手動で行う。このスクリプトはVMの作成のみを行う）。
.PARAMETER ConfigPath
    VM設定JSONファイルのパス（既定: config/vm-config.json）
.PARAMETER DryRun
    実際にはVMを作成せず、実行される gcloud コマンドを表示するだけのモード
.NOTES
    事前に gcloud SDK のインストールと `gcloud auth login` が必要。
#>

param(
    [string]$ConfigPath = "$PSScriptRoot\config\vm-config.json",
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

Write-Host "`n=== gcloud command ===" -ForegroundColor Cyan
Write-Host "gcloud $($gcloudArgs -join ' ')"

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
Write-Host "Next steps:"
Write-Host "  1. SSH in:"
Write-Host "       gcloud compute ssh $($config.vmName) --zone=$($config.zone) --project=$($config.projectId)"
Write-Host "  2. Clone this repo and run the remote-dev setup:"
Write-Host "       git clone https://github.com/Hanato238/My_init_setting.git"
Write-Host "       bash My_init_setting/ubuntu/setup.sh remote-dev"
Write-Host "  3. Follow the manual steps printed at the end of that script"
Write-Host "     (Tailscale auth/exit-node approval, starting orca-serve.service)."
