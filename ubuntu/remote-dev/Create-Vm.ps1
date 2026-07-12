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
.PARAMETER ProjectId
    GCPプロジェクトID。指定すると vm-config.json の projectId を上書きする。
    未指定時は $env:GCP_PROJECT_ID を使用する（それも無ければ vm-config.json の値を使う）。
.PARAMETER TailscaleAuthKey
    Tailscale の auth key。指定するとVM起動時にTailscale認証も自動化される
    （インスタンスメタデータ経由でVMに渡すため、リポジトリにはコミットしないこと）。
    未指定時は $env:TAILSCALE_AUTHKEY を使用する。
.PARAMETER Recreate
    同名VMが既に存在する場合、確認プロンプトの後に削除してから作り直す。
    未指定時、同名VMが存在するとエラーで終了する（誤って上書きしないための既定動作）。
.PARAMETER TailscaleApiKey
    Tailscale API access token（Personal access token、`tskey-api-...`）。
    -Recreate で既存VMを削除した際、Tailscale側に残る同名の古いデバイス（再作成後は
    ノードキーが変わるため新しいデバイスとして登録され、古い方はオフラインのまま残る）を
    Tailscale API経由で自動削除する。未指定時はこのクリーンアップをスキップし、
    古いデバイスは管理コンソールから手動削除が必要になる。
    未指定時は $env:TAILSCALE_API_KEY を使用する。
    auth keyと同様、vm-config.json（gitコミット対象）には書かず、パラメータか環境変数で渡すこと。
.PARAMETER DryRun
    実際にはVMを作成せず、実行される gcloud コマンドを表示するだけのモード
.NOTES
    事前に gcloud SDK のインストールと `gcloud auth login` が必要。
    vm-config.json の workspaceRepoUrl に public な GitHub リポジトリURLを設定しておくと、
    setup.sh が /etc/profile.d にログイン時clone用スクリプトを設置し、各ユーザーが
    最初にSSHログインしたタイミングで ~/workspace ディレクトリへ自動でcloneする
    （起動時点ではまだOSユーザーのホームディレクトリが存在しないことがあるため、
    ログイン時の遅延cloneにしている。private リポジトリの認証には未対応）。
    -Recreate はTailscale側のIPアドレスまでは引き継がない（VM再作成でtailscaledの
    ノードキーが失われるため、必ず新しいIPが割り当てられる）。-TailscaleApiKey を指定すると
    古いデバイスの自動削除だけは行われる。
#>

param(
    [string]$ConfigPath = "$PSScriptRoot\config\vm-config.json",
    [string]$ProjectId = $env:GCP_PROJECT_ID,
    [string]$TailscaleAuthKey = $env:TAILSCALE_AUTHKEY,
    [string]$TailscaleApiKey = $env:TAILSCALE_API_KEY,
    [switch]$Recreate,
    [switch]$DryRun
)

function Remove-TailscaleDevice {
    <#
    .SYNOPSIS
        Tailscale API経由で、指定したhostnameに一致するデバイスを削除する（-Recreate時、
        再作成前の古いデバイスをクリーンアップするため）。API呼び出しの失敗はVM作成処理
        全体を止めない（Write-Warningのみ）。
    #>
    param(
        [Parameter(Mandatory)][string]$Hostname,
        [Parameter(Mandatory)][string]$ApiKey
    )

    $headers = @{ Authorization = "Bearer $ApiKey" }
    try {
        $resp = Invoke-RestMethod -Uri "https://api.tailscale.com/api/v2/tailnet/-/devices" -Headers $headers -Method Get
    } catch {
        Write-Warning "Tailscale device list fetch failed - skipping old-device cleanup: $_"
        return
    }

    $staleDevices = @($resp.devices | Where-Object { $_.hostname -eq $Hostname })
    if ($staleDevices.Count -eq 0) {
        Write-Host "No existing Tailscale device found for hostname '$Hostname' - nothing to clean up." -ForegroundColor DarkGray
        return
    }

    foreach ($device in $staleDevices) {
        $addresses = $device.addresses -join ', '
        Write-Host "Removing stale Tailscale device '$($device.hostname)' ($addresses)..." -ForegroundColor Yellow
        try {
            Invoke-RestMethod -Uri "https://api.tailscale.com/api/v2/device/$($device.id)" -Headers $headers -Method Delete | Out-Null
            Write-Host "Removed." -ForegroundColor Green
        } catch {
            Write-Warning "Failed to remove Tailscale device $($device.id): $_"
        }
    }
}

if (-not (Test-Path $ConfigPath)) {
    Write-Error "Config file not found: $ConfigPath"
    exit 1
}

$config = Get-Content $ConfigPath -Raw | ConvertFrom-Json

if ($ProjectId) {
    $config | Add-Member -NotePropertyName projectId -NotePropertyValue $ProjectId -Force
}

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

$existingVm = gcloud compute instances describe $config.vmName `
    --zone=$($config.zone) --project=$($config.projectId) `
    --format="value(name)" 2>$null
if ($existingVm) {
    if (-not $Recreate) {
        Write-Error "VM '$($config.vmName)' already exists in zone $($config.zone). Use -Recreate to delete and recreate it, or delete it manually first."
        exit 1
    }
    if ($DryRun) {
        Write-Host "`n[DRY RUN] VM '$($config.vmName)' already exists; -Recreate would delete it before creating." -ForegroundColor Yellow
    } else {
        $confirm = Read-Host "VM '$($config.vmName)' already exists. Delete and recreate? (y/N)"
        if ($confirm -notin @('y', 'Y')) {
            Write-Host "Aborted." -ForegroundColor Yellow
            exit 0
        }
        Write-Host "Deleting existing VM '$($config.vmName)'..." -ForegroundColor Yellow
        gcloud compute instances delete $config.vmName --zone=$($config.zone) --project=$($config.projectId) --quiet
        if ($LASTEXITCODE -ne 0) {
            Write-Error "Failed to delete existing VM (exit code $LASTEXITCODE)."
            exit $LASTEXITCODE
        }

        if ($TailscaleApiKey) {
            Remove-TailscaleDevice -Hostname $config.vmName -ApiKey $TailscaleApiKey
        } else {
            Write-Host "NOTE: -TailscaleApiKey not set - the old Tailscale device (if any) was left in place." -ForegroundColor DarkGray
            Write-Host "      Remove it manually if needed: https://login.tailscale.com/admin/machines" -ForegroundColor DarkGray
        }
    }
}

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

# gcloud only accepts a single --metadata flag per invocation, so all key=value
# pairs (besides startup-script, which goes through --metadata-from-file) must
# be combined into one comma-joined argument.
$metadataPairs = @()
if ($TailscaleAuthKey) {
    $metadataPairs += "tailscale-authkey=$TailscaleAuthKey"
}
if ($config.workspaceRepoUrl) {
    $metadataPairs += "workspace-repo-url=$($config.workspaceRepoUrl)"
}
if ($metadataPairs.Count -gt 0) {
    $gcloudArgs += "--metadata=$($metadataPairs -join ',')"
}

Write-Host "`n=== gcloud command ===" -ForegroundColor Cyan
$printableArgs = $gcloudArgs | ForEach-Object {
    if ($_ -like '--metadata=*tailscale-authkey=*') {
        $_ -replace 'tailscale-authkey=[^,]*', 'tailscale-authkey=***'
    } else {
        $_
    }
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
if ($config.workspaceRepoUrl) {
    Write-Host ""
    Write-Host "workspaceRepoUrl was set, so ~/workspace will be auto-cloned with:" -ForegroundColor Green
    Write-Host "  $($config.workspaceRepoUrl)"
}
