<#
.SYNOPSIS
    GCP上にremote-agy運用VMを作成する（Tailscale SSH経由のCLI操作 + xrdpのGUI操作）
.DESCRIPTION
    config/vm-config.json の設定を使って `gcloud compute instances create` を実行する。
    startup-script.sh を起動スクリプトとして添付するため、VM起動後は自動的に
    ubuntu/remote-agy/setup.sh が実行され、Tailscale（tailscaled起動・IP forwarding・
    SSH有効化・exit node広告）、OpenSSHサーバー、xrdp（オンデマンドのXFCEセッション）、
    Antigravity CLI・uv・notebooklm-mcp-cli・gws のセットアップが完了する。
    -TailscaleAuthKey を指定した場合はTailscale認証も非対話で完了し、その後SSH経由で
    自動ポーリングし、このVMのTailscale IPが確認できた時点でそのアドレスを
    このスクリプトの出力にそのまま表示する（最大4分待機。タイムアウト時は手動確認コマンドを案内）。
    未指定の場合はTailscale認証のみ手動（SSHで入って `sudo tailscale up --ssh --advertise-exit-node`）
    が必要で、IPアドレスの自動表示も行われない。
    Exit node承認（Tailscale管理コンソール）は自動化されない、引き続き手動。
    xrdpはペアリング不要 - 初回SSHログイン後（~/.xsessionが書かれた後）、
    WindowsのリモートデスクトップアプリでこのVMのTailscale IP・ポート3389に
    接続するだけでよい（詳細はREADME.md参照）。
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
    Tailscale API access token（Personal access token、`tskey-api-...`）。2つの用途がある:
    (1) -TailscaleAuthKey が未指定の場合、このAPIキーを使ってTailscale APIから使い捨ての
    auth keyを自動生成し、Tailscale認証も自動化する（管理コンソールで毎回手動でauth keyを
    発行する必要がなくなる。生成失敗時は警告を出して手動認証にフォールバックする）。
    (2) -Recreate で既存VMを削除した際、Tailscale側に残る同名の古いデバイス（再作成後は
    ノードキーが変わるため新しいデバイスとして登録され、古い方はオフラインのまま残る）を
    Tailscale API経由で自動削除する。
    いずれも未指定時はスキップされる（認証キー生成はスキップされ手動認証が必要になり、
    古いデバイスは管理コンソールから手動削除が必要になる）。
    未指定時は $env:TAILSCALE_API_KEY を使用する。auth key生成には "Auth Keys" の書き込み
    権限を持つトークンが必要。
    auth keyと同様、vm-config.json（gitコミット対象）には書かず、パラメータか環境変数で渡すこと。
.PARAMETER DryRun
    実際にはVMを作成せず、実行される gcloud コマンドを表示するだけのモード
.NOTES
    事前に gcloud SDK のインストールと `gcloud auth login` が必要。
    vm-config.json の workspaceRepoUrls に public な GitHub リポジトリURLを配列で設定しておくと、
    setup.sh が /etc/profile.d にログイン時clone用スクリプトを設置し、各ユーザーが
    最初にSSHログインしたタイミングで ~/workspace ディレクトリへ自動でclone（複数可）する
    （起動時点ではまだOSユーザーのホームディレクトリが存在しないことがあるため、
    ログイン時の遅延cloneにしている。private リポジトリの認証には未対応）。
    remote-dev/life-osと同様、このVMもexit node化を前提とする
    （vm-config.jsonのenableIpForwardは既定でtrue。作成後は変更不可）。
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

function New-TailscaleAuthKey {
    <#
    .SYNOPSIS
        Auto-generates a one-time Tailscale auth key via the Tailscale API, so the
        VM can join the tailnet unattended without a human generating a key from
        the admin console before every run. Used as a fallback when -TailscaleAuthKey
        isn't supplied but -TailscaleApiKey is. The key is single-use (reusable:false)
        and expires in 1 hour, since it's only meant to cover this one VM boot.
        Returns $null (non-fatal) if the API call fails, e.g. the token lacks the
        "Auth Keys" write scope - the caller falls back to manual Tailscale auth.
    #>
    param(
        [Parameter(Mandatory)][string]$ApiKey
    )

    $headers = @{ Authorization = "Bearer $ApiKey" }
    $body = @{
        capabilities  = @{
            devices = @{
                create = @{
                    reusable      = $false
                    ephemeral     = $false
                    preauthorized = $true
                    tags          = @()
                }
            }
        }
        expirySeconds = 3600
    } | ConvertTo-Json -Depth 5

    try {
        $resp = Invoke-RestMethod -Uri "https://api.tailscale.com/api/v2/tailnet/-/keys" `
            -Headers $headers -Method Post -ContentType "application/json" -Body $body
        return $resp.key
    } catch {
        Write-Warning "Failed to auto-generate a Tailscale auth key via the API (falling back to manual auth): $_"
        return $null
    }
}

function Wait-TailscaleIp {
    <#
    .SYNOPSIS
        Polls the VM over SSH until `tailscale ip -4` succeeds, then returns that
        address. Only meaningful when Tailscale auth was automated
        (-TailscaleAuthKey) - otherwise auth itself is a manual step and this
        would just time out. Returns $null on timeout so the caller can fall
        back to manual instructions.
    #>
    param(
        [Parameter(Mandatory)][string]$VmName,
        [Parameter(Mandatory)][string]$Zone,
        [Parameter(Mandatory)][string]$ProjectId,
        [int]$TimeoutSeconds = 240,
        [int]$PollIntervalSeconds = 15
    )

    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    while ((Get-Date) -lt $deadline) {
        $out = gcloud compute ssh $VmName --zone=$Zone --project=$ProjectId --quiet `
            --command "tailscale ip -4" 2>$null
        if ($LASTEXITCODE -eq 0 -and $out) {
            return ($out | Select-Object -First 1)
        }
        Start-Sleep -Seconds $PollIntervalSeconds
    }
    return $null
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

if (-not $TailscaleAuthKey -and $TailscaleApiKey) {
    Write-Host "No -TailscaleAuthKey supplied, but -TailscaleApiKey is available - auto-generating a one-time auth key so this VM joins the tailnet automatically..." -ForegroundColor Cyan
    $TailscaleAuthKey = New-TailscaleAuthKey -ApiKey $TailscaleApiKey
    if ($TailscaleAuthKey) {
        Write-Host "Auth key generated - Tailscale auth will be automated for this VM." -ForegroundColor Green
    } else {
        Write-Host "Auth key generation failed - Tailscale auth will remain a manual step (see below)." -ForegroundColor Yellow
    }
}

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

if ($config.preemptible) {
    # 安価だがGCPの都合で随時停止されうる（最大稼働24時間）。exit node/GUI用途では
    # 停止時にTailscale接続・RDPセッションが切れる点に注意
    $gcloudArgs += "--preemptible"
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
if ($config.workspaceRepoUrls -and $config.workspaceRepoUrls.Count -gt 0) {
    $metadataPairs += "workspace-repo-urls=$($config.workspaceRepoUrls -join ' ')"
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
if ($config.preemptible) {
    Write-Host "This VM is preemptible: GCP can stop it at any time (and will force-stop it" -ForegroundColor Yellow
    Write-Host "after at most 24h of runtime). SSH/Tailscale/RDP sessions will drop when that" -ForegroundColor Yellow
    Write-Host "happens; restart the VM (or re-run this script) to bring it back." -ForegroundColor Yellow
}
Write-Host "The startup script bootstraps SSH + Tailscale + xrdp +"
Write-Host "Antigravity dev tooling automatically on first boot (usually takes a few"
Write-Host "minutes - installing the XFCE desktop takes longer than remote-dev/life-os)."
Write-Host "SSH in (via gcloud, over eth0) to check progress:"
Write-Host "  gcloud compute ssh $($config.vmName) --zone=$($config.zone) --project=$($config.projectId)"
Write-Host "  sudo journalctl -u google-startup-scripts -f"
Write-Host ""
if ($TailscaleAuthKey) {
    Write-Host "-TailscaleAuthKey was supplied, so Tailscale auth is automated too." -ForegroundColor Green

    Write-Host "`nWaiting for this VM to get a Tailscale IP so it can be shown automatically"
    Write-Host "(SSH + Tailscale auth - can take a minute or two)..."
    $tsIp = Wait-TailscaleIp -VmName $config.vmName -Zone $config.zone -ProjectId $config.projectId
    if ($tsIp) {
        Write-Host "`n=== Tailscale IP ===" -ForegroundColor Green
        Write-Host "  $tsIp"
        Write-Host "Connect from the client PC (over the tailnet) with:"
        Write-Host "  tailscale ssh $($config.vmName)"
        Write-Host "  ssh $tsIp"
    } else {
        Write-Host "`nCould not fetch the Tailscale IP automatically (timed out). Check manually:" -ForegroundColor Yellow
        Write-Host "  gcloud compute ssh $($config.vmName) --zone=$($config.zone) --project=$($config.projectId)"
        Write-Host "  tailscale ip -4"
    }
} else {
    Write-Host "No -TailscaleAuthKey supplied, so Tailscale auth is NOT automated." -ForegroundColor Yellow
    Write-Host "After SSH-ing in (via gcloud), authenticate manually:"
    Write-Host "  sudo tailscale up --ssh --advertise-exit-node"
}
Write-Host ""
Write-Host "Remaining manual steps (either way):"
Write-Host "  1. If this VM should be a Tailscale exit node, approve it in the Tailscale"
Write-Host "     admin console (advertisement alone isn't enough)."
Write-Host "  2. GUI access needs no pairing - after your first SSH login (so"
Write-Host "     ~/.xsession gets written), open Windows' Remote Desktop Connection"
Write-Host "     (mstsc) and connect to this VM's Tailscale IP on port 3389."
if ($config.workspaceRepoUrls -and $config.workspaceRepoUrls.Count -gt 0) {
    Write-Host ""
    Write-Host "workspaceRepoUrls was set, so ~/workspace will be auto-cloned with:" -ForegroundColor Green
    foreach ($url in $config.workspaceRepoUrls) {
        Write-Host "  $url"
    }
}
