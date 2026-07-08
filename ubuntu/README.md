# ubuntu/ — WSL Ubuntu セットアップスクリプト

WSL2 上の Ubuntu で、devcontainer / Docker を使ったコード開発環境を構築するためのスクリプト群。

## 実行順序

新規セットアップ時は以下の順番で実行する:

```bash
bash installer/install_apps.sh          # 1. パッケージ・言語ランタイム
bash settings/set_workspace.sh         # 2. 作業ディレクトリ
bash settings/set_aliases.sh           # 3. シェルエイリアス・環境変数ロード
bash installer/initialize_security.sh  # 4. Bitwarden → ~/.secrets
bash installer/install_docker.sh       # 5. Docker Desktop + devcontainer CLI
```

GCP VM等、特定用途のマシン（プロジェクト）をセットアップする場合は、上記とは別に単体で実行する:

```bash
bash setup.sh remote-dev
```

### 新しいプロジェクト（VM）を追加する

`setup.sh`は「`ubuntu/<name>/install.sh`が存在すれば`setup.sh <name>`で呼び出せる」という規約ベースで動く。`apps`/`mcp`/`aliases`等の全プロジェクト共通の項目とは別に、プロジェクト固有の構成は`ubuntu/<name>/`配下に一式まとめる。

```
ubuntu/<name>/
├── install.sh       # 必須。setup.sh <name> から呼ばれるエントリーポイント
├── packages.sh       # 任意。apt パッケージ一覧など install.sh から source する
├── config/           # 任意。VM作成パラメータ等
└── README.md         # 任意。使い方
```

`ubuntu/<name>/install.sh`を追加するだけでよく、`setup.sh`自体の編集は不要（`case`文には手を入れない）。既存の`remote-dev/`が実例。

---

## スクリプト詳細

### `install_apps.sh` — 基本パッケージのインストール

開発に必要な共通ツールを一括インストールする。

| ステップ | 内容 |
|---------|------|
| apt install | git, curl, vim, tree, jq, wget, unzip, **tmux**, build-essential, gnupg など |
| Python 3.12 | Deadsnakes PPA 経由でインストール。他バージョンは `uv python install 3.x` で管理 |
| Node.js LTS | NodeSource 経由でインストール |
| uv | Astral 製 Python パッケージ・バージョンマネージャー（`$HOME/.local/bin` にインストール） |
| Rust | rustup で非インタラクティブインストール（`-y`）。同セッション内で `cargo` が使えるよう `source "$HOME/.cargo/env"` を実行 |
| Claude Code | `npm install -g @anthropic-ai/claude-code` |
| Gemini CLI | `npm install -g @google/gemini-cli` |

**WSL 固有の注意点**: `fail2ban` や `systemctl` は WSL 環境では動作しないため含まない。

```bash
bash install_apps.sh
# 完了後の確認
node --version && claude --version && gemini --version
rustc --version && uv --version
```

---

### `setup_workspace.sh` — ワークスペースディレクトリ設定

`~/workspace` を作成し、シェル起動時に自動で移動するよう `~/.bashrc` に追記する。

**追記される内容:**

```bash
workspace="$HOME/workspace"   # $workspace 変数
cd "$HOME/workspace"          # 起動時に workspace へ移動
```

- 既に設定済みの場合は何もしない（冪等）

---

### `setup_aliases.sh` — シェルエイリアスと環境変数ロード

`~/.bashrc` に WSL 向けのエイリアスと関数群を追記する。マーカー `# === WSL Aliases ===` で管理し、重複実行しても二重登録されない。

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
sync_api_keys        # エイリアス経由（setup_aliases.sh セットアップ後）
# または直接
bash initialize_security.sh && source ~/.secrets
```

---

### `install_docker.sh` — Docker Engine (WSL2 ネイティブ)

Docker Desktop 不要。WSL2 の Ubuntu に Docker Engine を直接インストールする。ターミナルから `docker run` でコンテナを起動して隔離環境を作るための設計。

**スクリプトの処理（冪等）:**
1. systemd が未起動の場合 → `/etc/wsl.conf` に `systemd=true` を追記し、WSL 再起動を促して終了
2. Docker Engine を公式リポジトリからインストール
3. `docker` グループへ追加（sudo なしで使えるようにする）
4. Docker サービスを有効化・起動

```bash
bash installer/install_docker.sh
# ※ 初回は WSL 再起動後に再実行が必要な場合あり

# 確認
docker run --rm hello-world
```

**基本的な使い方:**
```bash
# プロジェクトディレクトリをマウントしてコンテナに入る
docker run -it --rm -v $(pwd):/workspace -w /workspace node:20 bash

# コンテナ内で Claude Code を起動
npm install -g @anthropic-ai/claude-code
claude
```

---

### `setup_gui.sh` — GUIデスクトップ環境（オプション）

Lubuntu デスクトップと GUI アプリをインストールする。通常の WSL 開発には不要。Chrome Remote Desktop でリモートデスクトップを使う場合などに利用する。

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
bash setup_gui.sh
# 完了後に再起動が必要
```

---

### `remote-dev/` — リモート開発環境セットアップ（GCP VM 向け・オプション）

GCP等のUbuntu VMを、Tailscale経由で外部デバイスからClaude Code / Orcaを操作するリモート開発機にするためのプロジェクト。`setup.sh remote-dev` で`remote-dev/install.sh`が呼ばれる。

VMインスタンス自体をまだ作成していない場合は、先に [`remote-dev/README.md`](remote-dev/README.md)（Windows側・gcloud使用の`Create-Vm.ps1`）でVMを作成する。

**構成:**

```
remote-dev/
├── install.sh          # setup.sh remote-dev のエントリーポイント（OS側セットアップ）
├── packages.sh          # apt パッケージ一覧（curl, libfuse2, xvfb）
├── config/vm-config.json  # VM作成パラメータ（Create-Vm.ps1用）
├── Create-Vm.ps1        # gcloudでVMを作成するラッパー（Windows側）
└── README.md
```

**`install.sh`がインストールするもの:**

| 項目 | 内容 |
|------|------|
| apt パッケージ | `packages.sh` の一覧（curl, libfuse2, xvfb） |
| Tailscale | 公式インストールスクリプト経由。IP forwarding も有効化（exit node用） |
| Orca | headless AppImage を `/opt/orca` に配置し、専用ユーザー `orca` で `orca-serve.service`（systemd）として常時起動 |

```bash
bash setup.sh remote-dev
```

**自動化されない手動ステップ（実行後に表示される）:**
1. GCP側でインスタンスの「IP forwarding」を有効化（作成時のみ設定可、既存インスタンスは変更不可。`remote-dev/Create-Vm.ps1` でVMを作成した場合は`vm-config.json`の`enableIpForward`で既に設定済み）
2. `sudo tailscale up --ssh --advertise-exit-node` で認証・Tailscale管理コンソールでexit node承認
3. `sudo systemctl enable --now orca-serve.service` でOrcaサーバー起動、`sudo journalctl -u orca-serve -f` でペアリングURL確認

---

### `setup_nanoclaw.sh` — NanoClaw セットアップ（オプション）

Telegram ボットフレームワーク [NanoClaw](https://github.com/qwibitai/nanoclaw) をセットアップする。

- NVM + Node.js 24 + pnpm のインストール
- WSL2 環境では `api.telegram.org` の IP を `/etc/hosts` に追記（接続の安定化）
- `~/workspace/nanoclaw` にリポジトリをクローンして `nanoclaw.sh` を実行

```bash
bash setup_nanoclaw.sh
```
