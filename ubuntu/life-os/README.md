# life-os/ — GCP VM リモートpush専用環境セットアップ

GCP上にUbuntu VMを作成し、**Tailscale SSH経由でのみ**外部から接続できるようにした上で、
指定したリポジトリをclone済みの状態にしておくためのプロジェクト一式。
[`../remote-dev/`](../remote-dev/README.md) の簡易版で、Orca headless serverやDocker常駐は無い。
このVMの役割は「cloneしたリポジトリを保持し、人がTailscale SSHでログインして編集・pushする」
だけに絞っている。

`Create-Vm.ps1` はVM作成時に `startup-script.sh` を起動スクリプトとして添付するため、**VM起動後に自動的に**
`setup.sh`（Tailscale SSHセットアップ + リポジトリclone）が実行される。手動でSSHして叩く必要はない
（再実行しても安全な冪等スクリプトなので、SSHして`bash life-os/setup.sh`を手動で叩き直すことも可能）。

## 構成

```
life-os/
├── startup-script.sh       # GCE起動スクリプト。リポジトリをclone/pullしてsetup.shを実行する
├── setup.sh                # OS側セットアップ本体（Tailscale SSH + exit node + リポジトリclone）
├── packages.sh             # setup.sh が使う apt パッケージ一覧（curl, git, vim, ufw のみ）
├── config/
│   └── vm-config.json     # VM作成パラメータ（プロジェクトID、ゾーン等。Create-Vm.ps1用）
├── Create-Vm.ps1           # gcloudでVMを作成するラッパースクリプト（Windows/PowerShell側）
└── README.md
```

## remote-dev/ との違い

| 項目 | remote-dev | life-os |
|------|-----------|---------|
| 常駐サービス | `orca-serve.service`（Orca headless server） | なし |
| Docker | インストール・使用（`claude`関数のサンドボックス実行用） | インストールしない |
| 外部からの接続 | Tailscale経由でOrcaクライアントをペアリング | Tailscale SSHのみ |
| リポジトリの用途 | Orcaプロジェクト/worktree管理 + 対話編集用 | clone/push専用（人が直接編集） |
| git push認証 | 対象外（clone URLはpublic想定） | 手動セットアップ（`gh auth login`等）。後述 |

## 使い方

### 1. 事前準備

- Windows側に gcloud SDK をインストール（`windows/installer/packages/choco-packages.ps1` の `gcloudsdk`、または `choco install gcloudsdk`）
- `gcloud init` と `gcloud auth login` でログイン
- `config/vm-config.json` を編集し、`projectId` をプレースホルダーから実際の値に置き換える
- （任意）Tailscale認証も自動化したい場合は、Tailscale管理コンソール（Settings > Keys）で auth key を発行しておく
- `config/vm-config.json` の `workspaceRepoUrls` にcloneしたいpublicなGitHubリポジトリURLを配列で設定する
  （private リポジトリの場合、clone自体にも手動認証が必要になる。後述）

### 2. VM作成

```powershell
cd life-os
.\Create-Vm.ps1                                              # 作成（Tailscale認証は手動で残る）
.\Create-Vm.ps1 -ProjectId my-project-123456                 # projectIdをvm-config.jsonの値から上書き
.\Create-Vm.ps1 -TailscaleAuthKey tskey-auth-xxxxx            # Tailscale認証も自動化（Tailscale IPも自動表示）
.\Create-Vm.ps1 -Recreate                                     # 同名VMが既存なら確認の上、削除してから作り直す
.\Create-Vm.ps1 -Recreate -TailscaleApiKey tskey-api-xxxxx    # recreate時、Tailscale側の古いデバイスも自動削除
.\Create-Vm.ps1 -DryRun                                       # 実行されるgcloudコマンドの確認のみ
.\Create-Vm.ps1 -ConfigPath .\config\other-vm-config.json     # 別設定ファイルを使う場合
```

`-ProjectId` は未指定時 `$env:GCP_PROJECT_ID` を使う（それも無ければ `vm-config.json` の
`projectId` をそのまま使う）。`-TailscaleAuthKey` は未指定時 `$env:TAILSCALE_AUTHKEY` を使う。
auth keyは `vm-config.json`（gitコミット対象）には書かず、パラメータか環境変数で渡すこと。
インスタンスメタデータ経由でVMに渡されるため、VM上のメタデータサーバーから読める点に注意
（漏洩時の影響を抑えたい場合はTailscale側でreusable/expiryを短く設定するか、使用後にkeyを失効させる）。

同名VMが既に存在する場合、既定では誤って上書きしないようエラーで終了する。
`-Recreate`とTailscaleのIPアドレスについては[`../remote-dev/README.md`](../remote-dev/README.md)と同様
（VM再作成でノードキーが失われ、必ず新しいIPが割り当てられる）。

### 3. 起動確認・接続

VM作成から1〜2分後、（`-TailscaleAuthKey`指定時は自動表示される）Tailscale IPで接続する:

```bash
tailscale ssh life-os-vm     # または
ssh <tailscale-ip>
```

進捗確認や、Tailscale認証が手動の場合の作業は`gcloud compute ssh`（eth0経由・GCE OS Login）で行う:

```bash
gcloud compute ssh life-os-vm --zone=<zone> --project=<projectId>
sudo journalctl -u google-startup-scripts -f   # startup-script.sh の実行ログ
```

自動化されるもの: `tailscaled`起動・IP forwarding有効化・（`-TailscaleAuthKey`指定時のみ）
Tailscale認証と`--ssh --advertise-exit-node`・`ufw`の有効化（SSH+tailscale0のみ許可、他は拒否）・
`workspaceRepoUrls`で指定したリポジトリの、各SSHユーザーが最初にログインしたタイミングでの
`~/workspace/<リポジトリ名>`へのclone・ログイン時エイリアスの設置。

### 4. git push認証（手動セットアップ）

このVMは意図的に**git pushの認証情報を自動化していない**。理由は、`-TailscaleAuthKey`のような
instance metadata経由の値はVM上のメタデータサーバーから読めてしまうため、push権限を持つ
トークンやSSH秘密鍵をそこに乗せたくないため。

Tailscale SSHでログイン後、以下のいずれかを**一度だけ**行う:

```bash
gh auth login          # GitHub CLIでの認証（以降 git push がそのまま通る）
# または
# ~/.ssh/ に write権限を持つdeploy keyを配置し、リポジトリのremoteをSSH URLにする
```

この設定はVMのブートディスク上に保存されるため、**再ログインや再起動のたびに設定し直す必要はない**。
再設定が必要になるのは以下の場合のみ:

- `Create-Vm.ps1 -Recreate` でVMを削除・再作成した場合（ブートディスクが失われるため）
- PAT/deploy keyの有効期限が切れた場合

### 5. 残りの手動ステップ

1. `-TailscaleAuthKey` 未指定の場合のTailscale認証（`sudo tailscale up --ssh --advertise-exit-node`）
2. Tailscale管理コンソールでの、このVMのexit node承認（このVMは常にexit node化を前提としている）
3. git push認証（上記4.）

## vm-config.json の項目

| キー | 説明 | 例 |
|------|------|-----|
| `projectId` | GCPプロジェクトID（`-ProjectId` / `$env:GCP_PROJECT_ID` で上書き可） | `my-project-123456` |
| `zone` | 作成するゾーン | `asia-northeast1-a` |
| `vmName` | インスタンス名 | `life-os-vm` |
| `machineType` | マシンタイプ | `e2-micro` |
| `imageFamily` | OSイメージファミリー | `ubuntu-2204-lts` |
| `imageProject` | イメージ提供元プロジェクト | `ubuntu-os-cloud` |
| `diskSizeGb` | ブートディスクサイズ(GB)。省略時 `30` | `15` |
| `diskType` | ブートディスクタイプ。省略時 `pd-balanced` | `pd-standard` |
| `enableIpForward` | IP forwardingを有効化するか（exit node化に必須）。**作成後は変更不可** | `true` |
| `networkTags` | ネットワークタグ（ファイアウォールルール等で利用、省略可） | `["life-os"]` |
| `workspaceRepoUrls` | 自動cloneするpublic GitHubリポジトリURLの配列（省略可。privateリポジトリは未対応） | `["https://github.com/you/your-repo.git"]` |

`vm-config.json` は複数環境用にコピーして使ってもよい（例: `config/staging-vm-config.json`）。その場合は `Create-Vm.ps1 -ConfigPath` で明示的に指定する。
