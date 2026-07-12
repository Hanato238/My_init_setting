# remote-dev/ — GCP VM リモート開発環境セットアップ

GCP上にUbuntu VMを作成し、Tailscale + Orca headless server でリモート開発できるようにするためのプロジェクト一式。
`Create-Vm.ps1` はVM作成時に `startup-script.sh` を起動スクリプトとして添付するため、**VM起動後に自動的に**
`setup.sh`（Tailscale + Orca セットアップ）が実行される。手動でSSHして叩く必要はない
（再実行しても安全な冪等スクリプトなので、SSHして`bash remote-dev/setup.sh`を手動で叩き直すことも可能）。
詳細は[`../README.md`](../README.md)を参照。

## 構成

```
remote-dev/
├── startup-script.sh       # GCE起動スクリプト。リポジトリをclone/pullしてsetup.shを実行する
├── setup.sh                # OS側セットアップ本体（Tailscale + Orca セットアップ）
├── packages.sh             # setup.sh が使う apt パッケージ一覧
├── config/
│   └── vm-config.json     # VM作成パラメータ（プロジェクトID、ゾーン等。Create-Vm.ps1用）
├── Create-Vm.ps1           # gcloudでVMを作成するラッパースクリプト（Windows/PowerShell側）
└── README.md
```

## 使い方

### 1. 事前準備

- Windows側に gcloud SDK をインストール（`windows/installer/packages/choco-packages.ps1` の `gcloudsdk`、または `choco install gcloudsdk`）
- `gcloud init` と `gcloud auth login` でログイン
- `config/vm-config.json` を編集し、`projectId` をプレースホルダーから実際の値に置き換える
- （任意）Tailscale認証も自動化したい場合は、Tailscale管理コンソール（Settings > Keys）で auth key を発行しておく
- （任意）VM上に開発用ワークスペースを自動セットアップしたい場合は、`config/vm-config.json` の
  `workspaceRepoUrl` にcloneしたいpublicなGitHubリポジトリURLを設定しておく

### 2. VM作成

```powershell
cd remote-dev
.\Create-Vm.ps1                                              # 作成（Tailscale認証は手動で残る）
.\Create-Vm.ps1 -ProjectId my-project-123456                 # projectIdをvm-config.jsonの値から上書き
.\Create-Vm.ps1 -TailscaleAuthKey tskey-auth-xxxxx            # Tailscale認証も自動化
.\Create-Vm.ps1 -Recreate                                     # 同名VMが既存なら確認の上、削除してから作り直す
.\Create-Vm.ps1 -DryRun                                       # 実行されるgcloudコマンドの確認のみ
.\Create-Vm.ps1 -ConfigPath .\config\other-vm-config.json     # 別設定ファイルを使う場合
```

`-ProjectId` は未指定時 `$env:GCP_PROJECT_ID` を使う（それも無ければ `vm-config.json` の
`projectId` をそのまま使う）。`-TailscaleAuthKey` は未指定時 `$env:TAILSCALE_AUTHKEY` を使う。
auth keyは `vm-config.json`（gitコミット対象）には書かず、パラメータか環境変数で渡すこと。
インスタンスメタデータ経由でVMに渡されるため、VM上のメタデータサーバーから読める点に注意
（漏洩時の影響を抑えたい場合はTailscale側でreusable/expiryを短く設定するか、使用後にkeyを失効させる）。

同名VMが既に存在する場合、既定では誤って上書きしないようエラーで終了する。
`machineType`・`diskSizeGb`・`enableIpForward`など作成時にしか決められない設定を変更したい場合は
`-Recreate` を付けて実行する（確認プロンプトの後、既存VMを削除してから作り直す。`-DryRun`と併用すると
削除される旨の表示のみで実際には削除しない）。Tailscale認証など`setup.sh`の範囲の再設定であれば、
VMの削除・再作成は不要で、SSHして`setup.sh`を再実行するだけでよい（後述）。

### 3. 起動確認・残りの手動ステップ

VM作成から1〜2分後、SSHで進捗を確認できる:

```bash
gcloud compute ssh <vmName> --zone=<zone> --project=<projectId>
sudo journalctl -u google-startup-scripts -f   # startup-script.sh の実行ログ
sudo journalctl -u orca-serve -f               # Orcaのペアリングurlはここで確認
```

自動化されるもの: `tailscaled`起動・IP forwarding有効化・（`-TailscaleAuthKey`指定時のみ）Tailscale認証・
Orca headless AppImageのインストールと`orca-serve.service`の起動・`orca` CLIコマンドのPATH登録・
（`workspaceRepoUrl`指定時のみ）`~/workspace/<リポジトリ名>`へのリポジトリclone。

引き続き手動が必要なもの:
1. `-TailscaleAuthKey` 未指定の場合のTailscale認証（`sudo tailscale up --ssh --advertise-exit-node`）
2. このVMをexit nodeにしたい場合、Tailscale管理コンソールでの承認
3. 外部のOrcaクライアント（デスクトップ/モバイル）とのペアリング（上記のペアリングURLを使用）

## vm-config.json の項目

| キー | 説明 | 例 |
|------|------|-----|
| `projectId` | GCPプロジェクトID（`-ProjectId` / `$env:GCP_PROJECT_ID` で上書き可） | `my-project-123456` |
| `zone` | 作成するゾーン | `asia-northeast1-a` |
| `vmName` | インスタンス名 | `remote-dev-vm` |
| `machineType` | マシンタイプ | `e2-medium` |
| `imageFamily` | OSイメージファミリー | `ubuntu-2204-lts` |
| `imageProject` | イメージ提供元プロジェクト | `ubuntu-os-cloud` |
| `diskSizeGb` | ブートディスクサイズ(GB)。省略時 `30` | `30` |
| `diskType` | ブートディスクタイプ。省略時 `pd-balanced` | `pd-balanced` |
| `enableIpForward` | IP forwardingを有効化するか（exit node化に必須）。**作成後は変更不可** | `true` |
| `networkTags` | ネットワークタグ（ファイアウォールルール等で利用、省略可） | `["remote-dev"]` |
| `workspaceRepoUrl` | 自動cloneするpublic GitHubリポジトリのURL（省略可。privateリポジトリは未対応） | `https://github.com/you/your-repo.git` |

`vm-config.json` は複数環境用にコピーして使ってもよい（例: `config/staging-vm-config.json`）。その場合は `Create-Vm.ps1 -ConfigPath` で明示的に指定する。

`workspaceRepoUrl` を設定すると、`setup.sh` は `/etc/profile.d/` にログイン時clone用のスクリプトを設置する。
実際のcloneはVM起動時ではなく、**各ユーザーが最初にSSHログインしたタイミング**で `~/workspace/<リポジトリ名>` に
行われる（起動時点ではまだそのユーザーのホームディレクトリが存在しないことがあり、起動時に一度だけcloneする
方式だと取りこぼすため、ログイン時の遅延clone方式にしている）。`orca`のようなサービスアカウント
（`/usr/sbin/nologin`）は対話ログインしないため対象にならない。既にcloneされていればスキップされる（冪等）。
