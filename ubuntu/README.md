# ubuntu/ — WSL Ubuntu セットアップスクリプト

WSL2 上の Ubuntu で、devcontainer / Docker を使ったコード開発環境を構築するためのスクリプト群。

各プロジェクトは`ubuntu/<name>/setup.sh`をエントリーポイントとして持ち、`bash <name>/setup.sh [args...]`で直接実行する規約になっている。共通のディスパッチャーは存在しない。

```
ubuntu/<name>/
├── setup.sh          # 必須。bash <name>/setup.sh [args...] で実行するエントリーポイント
├── packages.sh       # 任意。apt パッケージ一覧など setup.sh から source する
├── config/           # 任意。VM作成パラメータ等
└── README.md         # 任意。使い方
```

新しいプロジェクトを追加するには`ubuntu/<name>/setup.sh`を置くだけでよい。

現在ある5プロジェクト:

| プロジェクト | 用途 |
|------------|------|
| [`wsl-setup/`](wsl-setup/) | WSLホスト共通のセットアップ（Orca・Claude Code・Antigravity CLI・gh 開発環境、ワークスペース、エイリアス、Bitwarden連携、MCP） |
| [`remote-dev/`](remote-dev/README.md) | GCP等のVMをTailscale経由のリモート開発機にする |
| [`life-os/`](life-os/README.md) | GCP等のVMをTailscale SSH専用のclone/push機にする（`remote-dev/`の簡易版・常駐サービス無し） |
| [`remote-agy/`](remote-agy/README.md) | GCP等のVMをTailscale SSH（CLI）+ xrdp（GUI）で操作するAntigravity CLI向け開発機にする |
| [`devbox/`](devbox/README.md) | ローカルDocker Engine上にtmux + Claude Code + Antigravity CLIのコンテナを立てて本リポジトリをマウントする（試験的） |
| [`nanoclaw/`](nanoclaw/) | Telegram ボットフレームワーク NanoClaw のセットアップ |

---

## `wsl-setup/` — WSLホスト共通セットアップ

新規セットアップ時は以下の順番で実行する（`bash wsl-setup/setup.sh all` でまとめて実行、または個別に）:

```bash
bash wsl-setup/setup.sh apps        # 1. 開発ツール (claude/agy/gh)・Docker Engine
bash wsl-setup/setup.sh workspace   # 2. 作業ディレクトリ
bash wsl-setup/setup.sh aliases     # 3. シェルエイリアス・環境変数ロード
bash wsl-setup/setup.sh security    # 4. Bitwarden Secrets Manager → ~/.secrets
bash wsl-setup/setup.sh mcp         # 5. Claude Code MCPサーバー設定
bash wsl-setup/setup.sh all         # 上記 apps/security/aliases/mcp/workspace を一括実行
bash wsl-setup/setup.sh update      # apps の再実行（ツール更新。Setup-Wsl.ps1 -Update から呼ばれる）
bash wsl-setup/setup.sh mount-workspace <path>  # (任意) Windows側workspaceをWSLの~/workspaceへbind mount
```

サブコマンドと実体ファイルの対応:

| サブコマンド | 実体 |
|------------|------|
| `apps` | `wsl-setup/install_apps.sh` |
| `workspace` | `wsl-setup/set_workspace.sh` |
| `mount-workspace` | `wsl-setup/mount_workspace.sh`（引数: Windows側workspaceのWSLパス。通常は`windows/settings/Set-WslWorkspaceMount.ps1`経由） |
| `aliases` | `wsl-setup/set_aliases.sh` |
| `security` | `wsl-setup/initialize_security.sh` |
| `mcp` | `wsl-setup/set_mcp_servers.sh` |
| `update` | `wsl-setup/install_apps.sh`（再実行） |
| `all` | 上記を順番に実行 |

各スクリプトは直接 `bash wsl-setup/<script>.sh` としても実行できる。

---

### `install_apps.sh` — 開発ツール・Docker Engine のインストール

Windows 上の Orca から WSL 内のリポジトリを開き、Claude Code / Antigravity CLI / gh で開発するための CLI ツールを入れる（GUI なし）。冪等なので `update` で再実行できる。

| ステップ | 内容 |
|---------|------|
| apt install | git（git-core PPA の最新版）, curl, vim, tree, jq, wget, unzip, tmux, ripgrep, build-essential, gnupg |
| Node.js LTS | nvm 経由でインストール |
| uv | Astral 製 Python パッケージ・バージョンマネージャー。Python 本体は `uv python install 3.x` で管理 |
| Claude Code | ネイティブインストーラー（`~/.local/bin/claude`、自動更新） |
| Antigravity CLI (`agy`) | 公式インストーラー（`~/.local/bin/agy`） |
| gh | 公式 apt リポジトリ（snap 版は入っていれば削除）。認証済みなら `gh auth setup-git` で git の credential helper に設定 |
| 並列 worktree 向け設定 | inotify 上限の引き上げ（`/etc/sysctl.d/99-inotify.conf`）、`git config --global worktree.useRelativePaths true` / `fetch.prune true` |
| Docker Engine (WSL2ネイティブ) | 公式リポジトリからインストール。`docker`グループへ追加、systemdがあればサービス有効化・起動 |

**WSL 固有の注意点**:
- `fail2ban` は WSL 環境では動作しないため含まない
- Docker サービスの有効化・起動には systemd が必要。未起動の場合は `/etc/wsl.conf` に `systemd=true` を追記し、WSL再起動（`wsl --shutdown`）後の再実行を促す

```bash
bash wsl-setup/setup.sh apps
# 完了後の確認
git --version && node --version && uv --version
claude --version && agy --version && gh --version && docker --version
```

**手動ステップ:** `gh auth login && gh auth setup-git`（未認証の場合）。

#### Orca (Windows) で使う

- リポジトリは WSL の `~/workspace`（ext4）に clone し、Orca からは `\\wsl$\Ubuntu\home\<user>\workspace\<repo>` を開く。`/mnt/c` 上（`mount-workspace` で bind mount した場合も含む）は git が遅く、パーミッションも崩れるため、worktree を並列で使う用途には向かない。
- worktree を作ったら、WSL 側で `git -C <worktree> status` が通ることを確認する。Windows 側の git が作った worktree は gitdir が UNC パスで記録され、WSL の git から開けないことがある（`worktree.useRelativePaths` で回避する想定）。
- 並列で claude / agy を動かすとメモリを多く使う。足りなければ Windows 側の `%USERPROFILE%\.wslconfig` の `[wsl2]` に `memory=` を設定する。

---

### `set_workspace.sh` — ワークスペースディレクトリ設定

`~/workspace` を作成し、シェル起動時に自動で移動するよう `~/.bashrc` に追記する（冪等）。

---

### `mount_workspace.sh` — Windows側workspaceをWSLにbind mount（オプション）

`set_workspace.sh`が作る`~/workspace`はWSL内だけの独立したディレクトリだが、こちらはWindows側の
`$HOME\workspace`（`windows/settings/Set-Workspace.ps1`が作成）を`~/workspace`に直接bind mountし、
**同一のディレクトリ**として扱えるようにする。`/etc/fstab`に永続化するため、`wsl --shutdown`や
再起動後も（WSL起動時に自動で）再マウントされる。

通常は手動で叩くのではなく、Windows側の`windows/settings/Set-WslWorkspaceMount.ps1`から
（Windowsパスの変換を済ませた上で）呼び出す:

```powershell
.\windows\settings\Set-WslWorkspaceMount.ps1
```

WSL側で直接叩く場合は、マウントしたいWindowsパスのWSL表記を明示する:

```bash
bash wsl-setup/setup.sh mount-workspace /mnt/c/Users/<user>/workspace
```

**注意:** `/mnt/c`配下（DrvFs）はデフォルトではUnixパーミッションやシンボリックリンクを正しく
保持できない。そこに置いたgitリポジトリで権限・シンボリックリンク絡みの挙動がおかしい場合は、
`/etc/wsl.conf`の`[automount]`に`options = "metadata"`を追加する（`/mnt/c`全体に影響する別途の変更、
本スクリプトでは行わない）ことを検討する。

---

### `set_aliases.sh` — シェルエイリアスと環境変数ロード

`~/.bashrc` に WSL 向けのエイリアスと関数群を追記する。マーカー `# === Shell Aliases v3 ===` で管理し、重複実行しても二重登録されない。

#### Windows アプリへのショートカット

WSL から Windows の実行ファイルを直接呼び出すエイリアス:

| コマンド | 起動するアプリ |
|---------|--------------|
| `chrome` | Google Chrome |
| `vscode` | Visual Studio Code |
| `docker-desktop` | Docker Desktop |
| `word` / `excel` / `powerpoint` / `onenote` / `outlook` | Microsoft Office 各アプリ |

URL を開くには `wslview`（`wslu` パッケージ）を使用。未インストールの場合は自動でインストールする。

#### URL ショートカット関数

`chatgpt`, `claude-chrome`, `gemini-chrome`, `github`, `gdrive`, `gmail`, `gcp` など、よく使うウェブサービスをコマンド一発で既定ブラウザで開く。

#### API キー管理関数

| 関数 | 説明 |
|------|------|
| `load_secret_environment` | `~/.secrets` を読み込んで環境変数に展開。シェル起動時に自動実行 |
| `sync_api_keys` | `initialize_security.sh` を再実行して Bitwarden Secrets Manager から最新のキーを取得し、現在のセッションに反映（アクセストークンの入力を求められる） |

---

### `initialize_security.sh` — Bitwarden Secrets Manager → ~/.secrets

Bitwarden Secrets Manager のプロジェクトに登録したシークレットを `~/.secrets` に書き出す。

**フロー:**

```
Bitwarden Secrets Manager (クラウド)
  └─ bws secret list（アクセストークンは環境変数 or 対話貼り付け・非保存）
      └─ SM secret の key/value
          └─ ~/.secrets に export KEY='value' 形式で書き出し (chmod 600, @sh で安全にクォート)
              └─ source ~/.secrets → 環境変数として利用可能
```

SM secret は素の key/value を持つため、旧 `bw` 方式の優先順位ロジック（`login.password` → `notes` → フィールド名マッチ）は廃止。
key が環境変数名として不正なものは警告してスキップする。

**アクセストークン:**
- 環境変数 `BWS_ACCESS_TOKEN` があればそれを使用（CI 向け）。無ければ非表示プロンプトで入力。
- スクリプトプロセス内のみ・非保存。トークンはマシンアカウント権限＝指定プロジェクトの**読み取りのみ**で、個人 Vault には一切アクセスしない。
- 旧方式にあった `--passwordenv BW_PASSWORD`（マスターパスワードを環境変数に置く）は撤廃。
- 対象プロジェクトを絞る場合は環境変数 `BWS_PROJECT`（名前 or GUID）。

**セキュリティ:**
- `~/.secrets` は `chmod 600`（オーナーのみ読み書き可）
- Git には含まれない（`.gitignore` 推奨）
- Secrets Manager が唯一の正（ローカルファイルを直接編集しない）

**事前準備（一度きり・手動）:** 旧 `api_keys` Vault フォルダのアイテムを Secrets Manager プロジェクトへ移行する
（アイテム名を secret の key、値を secret の value に。key は環境変数として有効な識別子にすること）。
`bws` 未インストールならスクリプトが `sdk-sm` リリースの musl バイナリを `~/.local/bin` に入れる。

```bash
# 手動で再同期する場合
sync_api_keys        # エイリアス経由（set_aliases.sh セットアップ後）
# または直接
bash wsl-setup/setup.sh security && source ~/.secrets
```

---

### `set_mcp_servers.sh` — Claude Code MCPサーバー設定

`shared/mcp.d/*.json` の内容をマージし、`~/.claude.json` の`mcpServers`に反映する。

---

## `remote-dev/` — リモート開発環境セットアップ（GCP VM 向け・オプション）

GCP等のUbuntu VMを、Tailscale経由で外部デバイスからClaude Code / Orcaを操作するリモート開発機にするためのプロジェクト。
`remote-dev/Create-Vm.ps1`（Windows側）でVMを作成すると、起動スクリプト経由で`setup.sh`（Tailscale + Orca セットアップ）が
**自動実行される**。手動でSSHして叩く必要はない（冪等スクリプトなので、SSHして`bash remote-dev/setup.sh`を手動で叩き直すことも可能）。

**構成:**

```
remote-dev/
├── startup-script.sh      # GCE起動スクリプト（repoをclone/pullしてsetup.shを実行）
├── setup.sh               # OS側セットアップ本体（Tailscale + Orca セットアップ）
├── packages.sh            # apt パッケージ一覧（curl, libfuse2, xvfb）
├── config/vm-config.json  # VM作成パラメータ（Create-Vm.ps1用）
├── Create-Vm.ps1        # gcloudでVMを作成するラッパー（Windows側）
└── README.md
```

**`setup.sh`がインストールするもの:**

| 項目 | 内容 |
|------|------|
| apt パッケージ | `packages.sh` の一覧（curl, libfuse2, xvfb） |
| Tailscale | 公式インストールスクリプト経由。IP forwarding も有効化（exit node用）。`Create-Vm.ps1 -TailscaleAuthKey` 指定時は認証も自動 |
| Orca | headless AppImage を `/opt/orca` に配置し、専用ユーザー `orca` で `orca-serve.service`（systemd）として自動起動 |
| Orca CLI | 同じAppImageを `/usr/local/bin/orca` にシンボリンク。`orca serve` に加え `orca worktree create` 等のCLIサブコマンドをシェルから直接実行可能に |

**自動化されない手動ステップ:**
1. `Create-Vm.ps1 -TailscaleAuthKey` を指定しなかった場合のTailscale認証（`sudo tailscale up --ssh --advertise-exit-node`）
2. このVMをexit nodeにしたい場合、Tailscale管理コンソールでの承認
3. 外部のOrcaクライアント（デスクトップ/モバイル）とのペアリング（`sudo journalctl -u orca-serve -f` でURL確認）

VMの作成（Windows側・gcloud SDK使用）については [`remote-dev/README.md`](remote-dev/README.md) を参照。

---

## `life-os/` — clone/push専用VMセットアップ（GCP VM 向け・オプション）

`remote-dev/`の簡易版。GCP等のUbuntu VMを、**Tailscale SSH経由でのみ**外部から接続できるようにし、
指定したリポジトリをclone済みの状態にしておくためのプロジェクト。Orca headless serverやDocker常駐は
無く、常駐サービスが無い分`remote-dev/`より最小構成。役割は「cloneしたリポジトリを保持し、人が
Tailscale SSHでログインして編集・pushする」だけ。このVMは常にTailscale exit nodeとしての利用を
前提としている（Tailscale管理コンソールでの承認は引き続き手動）。

**構成:**

```
life-os/
├── startup-script.sh      # GCE起動スクリプト（repoをclone/pullしてsetup.shを実行）
├── setup.sh               # OS側セットアップ本体（Tailscale SSH + exit node + リポジトリclone）
├── packages.sh            # apt パッケージ一覧（curl, git, vim, ufw のみ）
├── config/vm-config.json  # VM作成パラメータ（Create-Vm.ps1用）
├── Create-Vm.ps1         # gcloudでVMを作成するラッパー（Windows側）
└── README.md
```

**git pushの認証は意図的に自動化していない**（手動セットアップ方式）: Tailscale SSHでログイン後、
`gh auth login` またはSSH deploy keyの設置を一度だけ行えばよく、その設定はブートディスク上に
永続する（`-Recreate`でディスクごと作り直した場合のみ再設定が必要）。詳細は
[`life-os/README.md`](life-os/README.md) を参照。

---

## `remote-agy/` — Antigravity CLI向けリモート開発環境セットアップ（GCP VM 向け・オプション）

GCP等のUbuntu VMを、クライアントPCから**Tailscale SSH（CLI）**と**xrdp（GUI）**の
両方で操作できるリモート開発機にするためのプロジェクト。Antigravity CLI（`agy`）・uv・
notebooklm-mcp-cli・gws（`@googleworkspace/cli`）を導入する。`remote-dev`/`life-os`と同様、
このVMもTailscale exit nodeとしての利用を前提としている。`remote-agy/Create-Vm.ps1`
（Windows側）でVMを作成すると、起動スクリプト経由で`setup.sh`が**自動実行される**。
手動でSSHして叩く必要はない（冪等スクリプトなので、SSHして`remote-agy/setup.sh`を
手動で叩き直すことも可能）。

**構成:**

```
remote-agy/
├── startup-script.sh      # GCE起動スクリプト（repoをclone/pullしてsetup.shを実行）
├── setup.sh               # OS側セットアップ本体（SSH + Tailscale + xrdp + 開発ツール）
├── packages.sh            # apt パッケージ一覧（openssh-server, ufw, xfce4, xrdp等）
├── config/vm-config.json  # VM作成パラメータ（Create-Vm.ps1用）
├── Create-Vm.ps1          # gcloudでVMを作成するラッパー（Windows側）
└── README.md
```

**`setup.sh`がインストールするもの:**

| 項目 | 内容 |
|------|------|
| apt パッケージ | `packages.sh` の一覧（openssh-server, ufw, xfce4, xrdp等） |
| Tailscale | 公式インストールスクリプト経由。IP forwardingも有効化（exit node用）。`Create-Vm.ps1 -TailscaleAuthKey` 指定時は`--ssh --advertise-exit-node`での認証も自動 |
| xrdp | RDP接続時のみXFCEセッションを起動（Chrome Remote Desktopと違い常駐しない）。ペアリング不要 - Windows標準のリモートデスクトップ接続からTailscale IP・ポート3389にそのまま接続できる |
| 開発ツール | uv・Antigravity CLI（`agy`）・notebooklm-mcp-cli（uv tool）・gws（npmパッケージ`@googleworkspace/cli`）を`/usr/local/bin`配下に配置し、全ログインユーザーから利用可能に |

**自動化されない手動ステップ:**
1. `Create-Vm.ps1 -TailscaleAuthKey` を指定しなかった場合のTailscale認証（`sudo tailscale up --ssh --advertise-exit-node`）
2. このVMをexit nodeにしたい場合、Tailscale管理コンソールでの承認

VMの作成（Windows側・gcloud SDK使用）については [`remote-agy/README.md`](remote-agy/README.md) を参照。

---

## `nanoclaw/` — NanoClaw セットアップ（オプション）

Telegram ボットフレームワーク [NanoClaw](https://github.com/qwibitai/nanoclaw) をセットアップする。

- NVM + Node.js 24 + pnpm のインストール
- WSL2 環境では `api.telegram.org` の IP を `/etc/hosts` に追記（接続の安定化）
- `~/workspace/nanoclaw` にリポジトリをクローンして `nanoclaw.sh` を実行

```bash
bash nanoclaw/setup.sh
```
