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
  `workspaceRepoUrls` にcloneしたいpublicなGitHubリポジトリURLを配列で設定しておく（複数可）

### 2. VM作成

```powershell
cd remote-dev
.\Create-Vm.ps1                                              # 作成（Tailscale認証は手動で残る）
.\Create-Vm.ps1 -ProjectId my-project-123456                 # projectIdをvm-config.jsonの値から上書き
.\Create-Vm.ps1 -TailscaleAuthKey tskey-auth-xxxxx            # Tailscale認証も自動化（Orcaペアリング情報も自動表示）
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
`machineType`・`diskSizeGb`・`enableIpForward`など作成時にしか決められない設定を変更したい場合は
`-Recreate` を付けて実行する（確認プロンプトの後、既存VMを削除してから作り直す。`-DryRun`と併用すると
削除される旨の表示のみで実際には削除しない）。Tailscale認証など`setup.sh`の範囲の再設定であれば、
VMの削除・再作成は不要で、SSHして`setup.sh`を再実行するだけでよい（後述）。

**`-Recreate`とTailscaleのIPアドレスについて**: VMを削除して作り直すと`tailscaled`のノードキーが
失われるため、新しいVMは必ず新しいTailscale IPで登録される（同じIPの再利用はできない）。古い方の
デバイスはTailscale管理コンソールに未接続（offline）のまま残り続けるので、`-TailscaleApiKey`に
[Tailscale管理コンソール](https://login.tailscale.com/admin/settings/keys)で発行したAPI access
token（`tskey-api-...`）を渡すと、`-Recreate`実行時にVM名と同じhostnameの古いデバイスをAPI経由で
自動削除する（未指定時はスキップされ、手動削除が必要）。`$env:TAILSCALE_API_KEY`でも指定可能。
auth keyと同様、コミットせずパラメータか環境変数で渡すこと。

### 3. 起動確認・残りの手動ステップ

VM作成から1〜2分後、SSHで進捗を確認できる:

```bash
gcloud compute ssh <vmName> --zone=<zone> --project=<projectId>
sudo journalctl -u google-startup-scripts -f   # startup-script.sh の実行ログ
sudo journalctl -u orca-serve -f               # Orcaのペアリングurlはここで確認
```

自動化されるもの: `tailscaled`起動・IP forwarding有効化・（`-TailscaleAuthKey`指定時のみ）Tailscale認証・
Orca headless AppImageのインストールと`orca-serve.service`の起動・`orca` CLIコマンドのPATH登録・
ログイン時エイリアス（後述）の設置・
（`workspaceRepoUrls`指定時のみ）各リポジトリの`/home/orca/workspace/<リポジトリ名>`（Orca用）と
`~/workspace/<リポジトリ名>`（SSHユーザー用）へのclone・
git/vim/python3のインストール・Node.js(LTS)/Docker Engine/GitHub CLI(`gh`)のインストール・
Claude Code CLI(`claude`)とClaude Agent SDK(npm/pip)のインストール・LINE LIFF SDK(npm)の
グローバルインストール・Antigravity CLIのインストール。

**Orcaペアリング情報の自動表示**: `-TailscaleAuthKey`を指定した場合、`Create-Vm.ps1`はVM作成後
SSH経由で`orca-serve`が起動するまで自動でポーリングし（最大4分）、起動でき次第そのログ
（ペアリングURL/アドレスを含む）をそのままコンソールに表示する。タイムアウトした場合は上記の
手動確認コマンドを案内する。`-TailscaleAuthKey`未指定時はTailscale認証自体が手動のため
`orca-serve`が起動せず、この自動表示は行われない（手動で`sudo journalctl -u orca-serve -f`を確認する）。

**ログイン時エイリアス**: `orca-serve.service`は専用の非rootユーザー`orca`で動作する
（対話ログインユーザーとは意図的に分離。理由は下記）。`setup.sh`は`/etc/profile.d/90-remote-dev-aliases.sh`
を設置し、対話ログインする各ユーザーのシェルに以下を追加する（`orca`ユーザー自身は
`nologin`のため対象外）:

| エイリアス/関数 | 内容 |
|---|---|
| `orca <サブコマンド>` | `sudo -u orca -H /usr/local/bin/orca <サブコマンド>` を実行する関数。`orca-runtime.json`が`orca`ユーザーのホーム配下に書かれるため、CLIも同じユーザーで実行しないと見つからない |
| `orca-status` | `sudo systemctl status orca-serve` |
| `orca-restart` | `sudo systemctl restart orca-serve` |
| `orca-logs` | `sudo journalctl -u orca-serve -f`（ペアリングURL確認用） |
| `ts-ip` | `tailscale ip -4` |
| `ts-status` | `tailscale status` |
| `claude [dir] [--as-host] [--sbx] [--rebuild]` | `windows/settings/Set-Aliases.ps1`の`claude`関数の移植（後述） |
| `enable-tailnet-port <port> [tcp\|udp]` | tailnetからのみ到達可能な`ufw`許可ルールを追加。詳細は[`../../TAILNET-PORTS.md`](../../TAILNET-PORTS.md) |
| `get-tailnet-ports` | `enable-tailnet-port`で追加したルール一覧を表示 |

**`claude`関数**: 対象ディレクトリに`.devcontainer/docker-compose.yml`があればそれを
`docker compose`で起動し`zellij`経由で接続する（Windows版と同じ挙動）。無ければ、
このVMには`sbx`（Windows専用のサンドボックスツール）が無いため、代わりにディレクトリ単位の
Dockerコンテナ（`claude-sandbox`イメージ、初回のみビルド）を作成し、以降は`docker exec`で
使い回す。`--sbx`を付けると`--permission-mode auto`付きで実行する（Windows版の`-Sbx`相当）。
`--as-host`はDockerを使わずホスト上の`claude`を直接実行し、`--rebuild`はサンドボックス
コンテナ/イメージ（または`.devcontainer`側）を作り直す。

**`orca-serve`を対話ログインユーザーと同じユーザーで動かさない理由**: このVMでは実験的に
Webサーバーとして一部ポートを公開する可能性があるため、リモート操作でクリック/入力を
自動実行するOrcaと同一ユーザーで動かすと、どちらかが侵害された際にもう一方（SSH鍵や
公開中のWebサーバー等）まで巻き添えになるリスクが上がる。ユーザーを分離したまま、
上記の`orca()`関数で手間だけを減らしている。

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
| `machineType` | マシンタイプ | `e2-micro` |
| `imageFamily` | OSイメージファミリー | `ubuntu-2204-lts` |
| `imageProject` | イメージ提供元プロジェクト | `ubuntu-os-cloud` |
| `diskSizeGb` | ブートディスクサイズ(GB)。省略時 `30` | `15` |
| `diskType` | ブートディスクタイプ。省略時 `pd-balanced` | `pd-standard` |
| `enableIpForward` | IP forwardingを有効化するか（exit node化に必須）。**作成後は変更不可** | `true` |
| `networkTags` | ネットワークタグ（ファイアウォールルール等で利用、省略可） | `["remote-dev"]` |
| `workspaceRepoUrls` | 自動cloneするpublic GitHubリポジトリURLの配列（省略可。privateリポジトリは未対応） | `["https://github.com/you/your-repo.git"]` |

`vm-config.json` は複数環境用にコピーして使ってもよい（例: `config/staging-vm-config.json`）。その場合は `Create-Vm.ps1 -ConfigPath` で明示的に指定する。

`workspaceRepoUrls` を設定すると、`setup.sh` は配列内の各リポジトリを**2箇所**にcloneする（用途が異なるため別々）:

1. **`/home/orca/workspace/<リポジトリ名>`**（`orca`ユーザー所有、VM起動時に即clone）: `orca-serve.service`は
   専用の`orca`システムユーザーで動作するため、他ユーザーのホームディレクトリ（既定で700/750）を読めない。
   OrcaクライアントからプロジェクトとしてAddし、`orca worktree create`等でworktree管理させる対象は
   ここを指定する。`orca`ユーザーのホームは`useradd --create-home`実行時点で存在するため、他ユーザーの
   ログイン待ちをせずVM起動時にcloneできる。
2. **`~/workspace/<リポジトリ名>`**（各SSHログインユーザー所有、**各ユーザーが最初にSSHログインしたタイミング**で
   clone）: `setup.sh`が`/etc/profile.d/`にログイン時clone用のスクリプトを設置し、人間が直接`cd`して
   編集する用。起動時点ではまだそのユーザーのホームディレクトリが存在しないことがあり、起動時に
   一度だけcloneする方式だと取りこぼすため、ログイン時の遅延clone方式にしている。

どちらもリポジトリごとに既にcloneされていればそのリポジトリだけスキップされる（冪等）。
