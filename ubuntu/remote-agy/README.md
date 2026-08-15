# remote-agy/ — Antigravity CLI 向け GCP VM リモート開発環境セットアップ

GCP上にUbuntu VMを作成し、クライアントPCから**Tailscale経由でSSH接続**（CLI操作）と
**xrdp経由でGUI接続**の両方ができるようにするためのプロジェクト一式。
Antigravity CLI（`agy`）・uv・notebooklm-mcp-cli・gws（`@googleworkspace/cli`）を導入し、
エージェント的な開発作業をこのVM上で行うことを想定している。`remote-dev`/`life-os`と同様、
このVMもTailscale exit nodeとしての利用を前提としている（Tailscale管理コンソールでの承認は
引き続き手動）。
`Create-Vm.ps1` はVM作成時に `startup-script.sh` を起動スクリプトとして添付するため、**VM起動後に自動的に**
`setup.sh`（SSH + Tailscale + xrdp + 開発ツール群のセットアップ）が実行される。
手動でSSHして叩く必要はない（再実行しても安全な冪等スクリプトなので、SSHして`bash remote-agy/setup.sh`を
手動で叩き直すことも可能）。詳細は[`../README.md`](../README.md)を参照。

## `remote-dev/` / `life-os/` との違い

| 項目 | remote-dev | life-os | remote-agy |
|------|-----------|---------|-----------|
| 常駐サービス | `orca-serve.service` | なし | `xrdp`（GUIセッション自体は接続時のみ起動） |
| CLI接続 | Tailscale（Orcaクライアントをペアリング） | Tailscale SSH | Tailscale SSH |
| GUI接続 | なし | なし | xrdp（Tailscale経由・ペアリング不要） |
| exit node化 | 前提 | 前提 | 前提（remote-dev/life-osと同様） |
| 主要ツール | Claude Code, Claude Agent SDK, Docker | （なし・clone/push専用） | Antigravity CLI (`agy`), uv, notebooklm-mcp-cli, gws (`@googleworkspace/cli`) |

GUIをほとんど使わない想定のため、Chrome Remote Desktop（ペアリングしておくと常時デスクトップ
セッションが動き続ける）ではなく**xrdp**を採用している。xrdpはRDP接続が来たときだけXFCEセッションを
起動し、切断すると終了するため、GUIを使わない間のオーバーヘッドがほぼ無い。ペアリング作業も不要で、
Windows標準のリモートデスクトップ接続（mstsc）からTailscale IP宛にそのまま接続できる。

## 構成

```
remote-agy/
├── startup-script.sh       # GCE起動スクリプト。リポジトリをclone/pullしてsetup.shを実行する
├── setup.sh                # OS側セットアップ本体（SSH + Tailscale + xrdp + 開発ツール）
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
cd remote-agy
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
`machineType`・`diskSizeGb`など作成時にしか決められない設定を変更したい場合は`-Recreate`を
付けて実行する（確認プロンプトの後、既存VMを削除してから作り直す。`-DryRun`と併用すると
削除される旨の表示のみで実際には削除しない）。Tailscale認証など`setup.sh`の範囲の再設定であれば、
VMの削除・再作成は不要で、SSHして`setup.sh`を再実行するだけでよい。

**`-Recreate`とTailscaleのIPアドレスについて**: VMを削除して作り直すと`tailscaled`のノードキーが
失われるため、新しいVMは必ず新しいTailscale IPで登録される（同じIPの再利用はできない）。古い方の
デバイスはTailscale管理コンソールに未接続（offline）のまま残り続けるので、`-TailscaleApiKey`に
[Tailscale管理コンソール](https://login.tailscale.com/admin/settings/keys)で発行したAPI access
token（`tskey-api-...`）を渡すと、`-Recreate`実行時にVM名と同じhostnameの古いデバイスをAPI経由で
自動削除する（未指定時はスキップされ、手動削除が必要）。`$env:TAILSCALE_API_KEY`でも指定可能。
auth keyと同様、コミットせずパラメータか環境変数で渡すこと。

### 3. 起動確認

VM作成から数分後（XFCEデスクトップのインストールが入る分、`remote-dev`/`life-os`より時間がかかる）、
SSHで進捗を確認できる:

```bash
gcloud compute ssh <vmName> --zone=<zone> --project=<projectId>
sudo journalctl -u google-startup-scripts -f   # startup-script.sh の実行ログ
```

自動化されるもの: `sshd`（`openssh-server`）の有効化・`tailscaled`起動・IP forwarding有効化・
（`-TailscaleAuthKey`指定時のみ）Tailscale認証(`--ssh --advertise-exit-node`)・`ufw`の有効化
（SSH+tailscale0のみ許可、他は拒否）・`xrdp`の有効化（TLS証明書読み取り用に`ssl-cert`グループへ
自動追加）・ログイン時の`~/.xsession`自動設置（xfce4-session指定）・uv（`/usr/local/bin`に配置）・
Antigravity CLI（`agy`）・notebooklm-mcp-cli（uv tool、`/usr/local/bin`に配置）・
Node.js(LTS)・gws（npmパッケージ`@googleworkspace/cli`）・ログイン時エイリアスの設置・
（`workspaceRepoUrls`指定時のみ）各リポジトリの`~/workspace/<リポジトリ名>`への
ログイン時clone。

**ログイン時エイリアス**: `setup.sh`は`/etc/profile.d/90-remote-agy-aliases.sh`を設置し、
対話ログインする各ユーザーのシェルに以下を追加する:

| エイリアス/関数 | 内容 |
|---|---|
| `ts-ip` | `tailscale ip -4` |
| `ts-status` | `tailscale status` |
| `xrdp-status` | `sudo systemctl status xrdp` |
| `enable-tailnet-port <port> [tcp\|udp]` | tailnetからのみ到達可能な`ufw`許可ルールを追加。詳細は[`../../TAILNET-PORTS.md`](../../TAILNET-PORTS.md) |
| `get-tailnet-ports` | `enable-tailnet-port`で追加したルール一覧を表示 |

### 4. CLI接続（Tailscale SSH）

```bash
tailscale ssh <vmName>     # または
ssh <tailscale-ip>
```

`-TailscaleAuthKey`を指定した場合、`Create-Vm.ps1`はVM作成後、Tailscale IPが確認できるまで
自動でポーリングし（最大4分）、確認でき次第そのアドレスと接続コマンドをコンソールに表示する。
未指定時は`sudo tailscale up --ssh --advertise-exit-node`を手動で実行する必要がある。

### 5. GUI接続（xrdp）— ペアリング不要

Chrome Remote Desktopと異なり、xrdpは**ペアリング作業が無い**。初回SSHログイン時に`~/.xsession`が
自動設置されるので、それ以降はいつでも以下だけでGUI接続できる:

1. このVMに一度SSHログインしておく（`~/.xsession`が書かれるのはこのタイミング。前述の
   ログイン時プロファイルスクリプトが自動で行う）。
2. クライアントPC（Windows）で標準の「リモートデスクトップ接続」（`mstsc`）を開き、
   このVMのTailscale IP（`tailscale ip -4`で確認）をポート3389で指定して接続する。
   OS標準ユーザー名・パスワードでログインする。
3. 切断すると裏のXFCEセッションも終了する（Chrome Remote Desktopのように常駐しない）。

### 6. 残りの手動ステップ

1. `-TailscaleAuthKey` 未指定の場合のTailscale認証（`sudo tailscale up --ssh --advertise-exit-node`）
2. このVMをexit nodeにしたい場合、Tailscale管理コンソールでの承認

## vm-config.json の項目

| キー | 説明 | 例 |
|------|------|-----|
| `projectId` | GCPプロジェクトID（`-ProjectId` / `$env:GCP_PROJECT_ID` で上書き可） | `my-project-123456` |
| `zone` | 作成するゾーン | `asia-northeast1-a` |
| `vmName` | インスタンス名 | `remote-agy-vm` |
| `machineType` | マシンタイプ。既定`e2-medium`(共有2vCPU・4GB RAM)。GUIは滅多に使わない前提の構成で、xrdpのXFCEセッションは接続時のみ起動するため待機中の負荷は小さい。不足/過剰な場合は`gcloud compute instances set-machine-type`でVM再作成無しに変更可能（要一時停止） | `e2-medium` |
| `imageFamily` | OSイメージファミリー | `ubuntu-2204-lts` |
| `imageProject` | イメージ提供元プロジェクト | `ubuntu-os-cloud` |
| `diskSizeGb` | ブートディスクサイズ(GB)。省略時 `30` | `30` |
| `diskType` | ブートディスクタイプ。省略時 `pd-balanced` | `pd-balanced` |
| `enableIpForward` | IP forwardingを有効化するか（exit node化に必須）。既定`true`。**作成後は変更不可** | `true` |
| `preemptible` | Preemptible VM（最大24h稼働・GCPの都合で随時停止されうる代わりに大幅割安）にするか。省略時`false`。停止するとTailscale/RDPセッションは切れる（再起動すれば復帰）。**作成後は変更不可**（切り替えるには`-Recreate`が必要） | `true` |
| `networkTags` | ネットワークタグ（ファイアウォールルール等で利用、省略可） | `["remote-agy"]` |
| `workspaceRepoUrls` | 自動cloneするpublic GitHubリポジトリURLの配列（省略可。privateリポジトリは未対応） | `["https://github.com/you/your-repo.git"]` |

`vm-config.json` は複数環境用にコピーして使ってもよい（例: `config/staging-vm-config.json`）。その場合は `Create-Vm.ps1 -ConfigPath` で明示的に指定する。
