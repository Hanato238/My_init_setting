# windows/ — Windows 11 セットアップスクリプト

PowerShell を使って Windows 11 の開発環境を一括構築するためのスクリプト群。

## エントリーポイント

PowerShell を**管理者として**起動してから実行する:

```powershell
# リモートから直接実行（新規 PC セットアップ時）
iex (iwr "https://raw.githubusercontent.com/hanato238/My_init_setting/main/windows/Start-Setup.ps1")

# ローカルから実行
Set-ExecutionPolicy Bypass -Scope Process -Force
& .\Start-Setup.ps1
```

`Start-Setup.ps1` が以下のスクリプトを順番に呼び出す:

```
Start-Setup.ps1
├── installer/Install-Chocolatey.ps1   # パッケージマネージャー
├── installer/Install-Apps.ps1         # アプリ一括インストール
├── installer/Install-Office.ps1       # Microsoft Office
├── settings/Set-Workspace.ps1         # ワークスペース設定
├── settings/Set-Aliases.ps1           # PowerShell プロファイル設定
├── settings/Set-DockerDesktop.ps1     # Docker Desktop WSL 連携
├── installer/Initialize-Security.ps1  # Bitwarden → SecretStore
├── installer/install-llmcli.ps1       # Claude Code / Gemini + MCP サーバー
└── settings/Set-McpServers.ps1        # 追加 MCP サーバー登録
```

---

## スクリプト詳細

### `installer/Install-Chocolatey.ps1` — Chocolatey インストール

Windows 向けパッケージマネージャー [Chocolatey](https://chocolatey.org/) をインストールする。未インストールの場合のみ実行する。

```powershell
& .\installer\Install-Chocolatey.ps1
choco --version  # 確認
```

---

### `installer/Install-Apps.ps1` — アプリ一括インストール

Chocolatey 経由でアプリを一括インストールし、npm でグローバルパッケージを追加する。

**Chocolatey でインストールするアプリ（主なもの）:**

| カテゴリ | アプリ |
|---------|--------|
| ブラウザ・クラウド | googlechrome, googledrive, gcloudsdk |
| 開発ツール | git, nodejs-lts, python312, uv, jq, curl, vim, vscode |
| コンテナ | docker-desktop, wsl-ubuntu-2204 |
| セキュリティ | bitwarden, bitwarden-cli |
| ユーティリティ | powertoys, tree, procmon, wireshark, gsudo |
| その他 | awscli, ngrok, expressvpn, spacedesk-server |

**PowerShell モジュール:**
- `Microsoft.PowerShell.SecretManagement` — シークレット管理の抽象レイヤー
- `Microsoft.PowerShell.SecretStore` — ローカル暗号化ストレージ

**npm グローバルパッケージ:**
- `@anthropic-ai/claude-code`
- `@anthropic-ai/sdk`
- `@google/gemini-cli`

---

### `installer/Install-Office.ps1` — Microsoft Office インストール

`app_data/configuration-Office2021Enterprise.xml` の設定を使い Microsoft Office 2021 Enterprise をインストールする。

---

### `installer/Install-Wsl.ps1` — WSL2 インストール

WSL2 を有効化し Ubuntu をインストールする。有効化後に再起動が必要。

```powershell
& .\installer\Install-Wsl.ps1
```

---

### `installer/Initialize-Security.ps1` — Bitwarden → SecretStore

Bitwarden の `api_keys` フォルダに保存した API キーを PowerShell SecretStore（`LocalStore` Vault）に取り込む。

**フロー:**

```
Bitwarden (クラウド)
  └─ bw login / unlock / sync
      └─ api_keys フォルダのアイテムを取得
          └─ SecretStore (LocalStore) に保存
              └─ Load-SecretEnvironment → 環境変数として利用可能
```

**値の取得優先順位:**
1. `login.password`
2. `notes`（Secure Note）
3. カスタムフィールド（名前が `value / api_key / secret / password / key` にマッチするもの）

**SecretStore の設定:**
- `Authentication None` — パスワード不要でアクセス可能
- `Interaction None` — 対話プロンプトを抑制

セットアップ後は PowerShell プロファイルから `Sync-ApiKeys` コマンドで再同期できる。

---

### `installer/install-llmcli.ps1` — LLM CLI + MCP サーバーセットアップ

Claude Code と Gemini CLI をインストールし、標準 MCP サーバーおよび拡張 MCP サーバーを登録する。

**標準 MCP サーバー（Claude・Gemini 両方に登録）:**

| サーバー | 役割 |
|---------|------|
| filesystem | ファイルシステムアクセス |
| memory | セッション間のメモリ管理 |
| sequential-thinking | 段階的思考サポート |
| fetch | URL コンテンツ取得 |
| git | Git 操作 |

**拡張 MCP サーバー（`Hanato238/mcp-servers` リポジトリ）:**

`~/workspace/mcp-servers` にクローンし、各ディレクトリをビルド・登録する。

| 拡張サーバー | 用途 |
|------------|------|
| brightdata | Web スクレイピング |
| drawio-mcp | Draw.io 図表操作 |
| perplexity-mcp | Perplexity AI 検索 |
| playwright-mcp | ブラウザ自動化 |
| notebooklm-mcp-cli | NotebookLM 操作 |
| context7 | ライブラリドキュメント参照 |
| desktop-commander | デスクトップ操作 |
| github | GitHub API 操作 |
| huggingface | HuggingFace 連携 |
| observability | ログ・モニタリング |

**エントリーポイントの自動検出:**
- `package.json` がある場合: `bin` → `main` → `dist/index.js` の順に探索
- `pyproject.toml` がある場合: `uv run` で実行

---

### `settings/Set-Workspace.ps1` — ワークスペース設定

`$HOME\workspace` ディレクトリを作成し、`$workspace` 変数を PowerShell プロファイルに追記する。

---

### `settings/Set-Aliases.ps1` — PowerShell プロファイル設定

PowerShell プロファイル（`$PROFILE`）を上書きし、エイリアスと関数を設定する。既存プロファイルは `.bak` としてバックアップされる。

**アプリエイリアス（主なもの）:**

| コマンド | 起動するアプリ |
|---------|--------------|
| `chrome` | Google Chrome |
| `vscode` | Visual Studio Code |
| `docker-desktop` | Docker Desktop |
| `claude` | Claude Code CLI |
| `gemini` | Gemini CLI |
| `bitwarden` | Bitwarden デスクトップ |
| `word` / `excel` / `powerpoint` / `onenote` / `outlook` | Microsoft Office 各アプリ |

**URL ショートカット関数:**
`chatgpt`, `claude-chrome`, `gemini-chrome`, `github`, `gdrive`, `gmail`, `gcp`, `gai` など。

**API キー管理関数:**

| 関数 | 説明 |
|------|------|
| `Load-SecretEnvironment` | SecretStore のシークレットを環境変数に展開。プロファイル読み込み時に自動実行 |
| `Sync-ApiKeys` | `Initialize-Security.ps1` を再実行して Bitwarden から最新キーを取得・反映 |

---

### `settings/Set-DockerDesktop.ps1` — Docker Desktop WSL 連携

Docker Desktop の設定ファイル（`%APPDATA%\Docker\settings-store.json`）を編集し、Ubuntu WSL ディストリビューションとの統合を有効化する。

設定変更後は Docker Desktop の再起動が必要。

---

### `settings/Set-DesktopEnv.ps1` — デスクトップ環境整理

デスクトップとタスクバーの既存ショートカット（`.lnk` / `.url`）を削除してクリーンアップする。ゴミ箱のショートカットは保持する。

管理者権限が必要。未実行の場合は自動で権限昇格ダイアログを表示する。

---

### `settings/Set-McpServers.ps1` — 追加 MCP サーバー登録

`settings/.mcp.json` に定義した MCP サーバーを `~/.claude.json` にマージする。`jq` を使って既存の設定を壊さずに `mcpServers` キーを上書きする。

```powershell
# カスタム MCP サーバーを追加する場合
# settings/.mcp.json を編集してから実行
& .\settings\Set-McpServers.ps1
```
