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

現在ある3プロジェクト:

| プロジェクト | 用途 |
|------------|------|
| [`wsl-setup/`](wsl-setup/) | WSLホスト共通のセットアップ（パッケージ、ワークスペース、エイリアス、Bitwarden連携、MCP、GUI） |
| [`remote-dev/`](remote-dev/README.md) | GCP等のVMをTailscale経由のリモート開発機にする |
| [`nanoclaw/`](nanoclaw/) | Telegram ボットフレームワーク NanoClaw のセットアップ |

---

## `wsl-setup/` — WSLホスト共通セットアップ

新規セットアップ時は以下の順番で実行する（`bash wsl-setup/setup.sh all` でまとめて実行、または個別に）:

```bash
bash wsl-setup/setup.sh apps        # 1. パッケージ・言語ランタイム・Docker Engine
bash wsl-setup/setup.sh workspace   # 2. 作業ディレクトリ
bash wsl-setup/setup.sh aliases     # 3. シェルエイリアス・環境変数ロード
bash wsl-setup/setup.sh security    # 4. Bitwarden → ~/.secrets
bash wsl-setup/setup.sh mcp         # 5. Claude Code MCPサーバー設定
bash wsl-setup/setup.sh gui         # 6. (任意) GUIデスクトップ環境。WSLでは自動スキップ
bash wsl-setup/setup.sh all         # 上記 apps/security/aliases/mcp/workspace(/gui) を一括実行
```

サブコマンドと実体ファイルの対応:

| サブコマンド | 実体 |
|------------|------|
| `apps` | `wsl-setup/install_apps.sh` |
| `workspace` | `wsl-setup/set_workspace.sh` |
| `aliases` | `wsl-setup/set_aliases.sh` |
| `security` | `wsl-setup/initialize_security.sh` |
| `mcp` | `wsl-setup/set_mcp_servers.sh` |
| `gui` | `wsl-setup/set_gui.sh`（WSL上では自動スキップ） |
| `all` | 上記を順番に実行（`gui`はWSL上ではスキップ） |

各スクリプトは直接 `bash wsl-setup/<script>.sh` としても実行できる。

---

### `install_apps.sh` — 基本パッケージ・Docker Engine のインストール

開発に必要な共通ツールを一括インストールする。

| ステップ | 内容 |
|---------|------|
| apt install | git, curl, vim, tree, jq, wget, unzip, **tmux**, build-essential, gnupg など |
| Python 3.12 | Deadsnakes PPA 経由でインストール。他バージョンは `uv python install 3.x` で管理 |
| Node.js LTS | nvm 経由でインストール |
| uv | Astral 製 Python パッケージ・バージョンマネージャー（`$HOME/.local/bin` にインストール） |
| Rust | rustup（snap）で非インタラクティブインストール |
| Claude Code / Gemini CLI / gh / ngrok | npm・snap経由でインストール |
| Docker Engine (WSL2ネイティブ) | 公式リポジトリからインストール。`docker`グループへ追加、systemdがあればサービス有効化・起動 |

**WSL 固有の注意点**:
- `fail2ban` は WSL 環境では動作しないため含まない
- Docker サービスの有効化・起動には systemd が必要。未起動の場合は `/etc/wsl.conf` に `systemd=true` を追記し、WSL再起動（`wsl --shutdown`）後の再実行を促す

```bash
bash wsl-setup/setup.sh apps
# 完了後の確認
node --version && claude --version && gemini --version
rustc --version && uv --version && docker --version
```

---

### `set_workspace.sh` — ワークスペースディレクトリ設定

`~/workspace` を作成し、シェル起動時に自動で移動するよう `~/.bashrc` に追記する（冪等）。

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
| `sync_api_keys` | `initialize_security.sh` を再実行して Bitwarden から最新のキーを取得し、現在のセッションに反映 |

---

### `initialize_security.sh` — Bitwarden → ~/.secrets

Bitwarden の `api_keys` フォルダに保存した API キーを `~/.secrets` に書き出す。

**フロー:**

```
Bitwarden (クラウド)
  └─ bw login / unlock / sync
      └─ api_keys フォルダのアイテムを取得
          └─ ~/.secrets に export KEY="value" 形式で書き出し (chmod 600)
              └─ source ~/.secrets → 環境変数として利用可能
```

**値の取得優先順位:**
1. `login.password`
2. `notes`（Secure Note）
3. カスタムフィールド（名前が `value / api_key / secret / password / key` にマッチするもの）

**セキュリティ:**
- `~/.secrets` は `chmod 600`（オーナーのみ読み書き可）
- Git には含まれない（`.gitignore` 推奨）
- Bitwarden が唯一の正（ローカルファイルを直接編集しない）

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

### `set_gui.sh` — GUIデスクトップ環境（オプション）

Lubuntu デスクトップと GUI アプリをインストールする。通常の WSL 開発には不要。Chrome Remote Desktop でリモートデスクトップを使う場合などに利用する。WSL上では`wsl-setup/setup.sh`が自動的にスキップする。

| インストール内容 |
|----------------|
| Lubuntu デスクトップ |
| Google Chrome |
| Chrome Remote Desktop |
| VSCode (snap) |
| Telegram Desktop (snap) |
| Zoom |
| Bitwarden GUI (snap) |
| TeamViewer |

```bash
bash wsl-setup/setup.sh gui
# 完了後に再起動が必要
```

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

## `nanoclaw/` — NanoClaw セットアップ（オプション）

Telegram ボットフレームワーク [NanoClaw](https://github.com/qwibitai/nanoclaw) をセットアップする。

- NVM + Node.js 24 + pnpm のインストール
- WSL2 環境では `api.telegram.org` の IP を `/etc/hosts` に追記（接続の安定化）
- `~/workspace/nanoclaw` にリポジトリをクローンして `nanoclaw.sh` を実行

```bash
bash nanoclaw/setup.sh
```
