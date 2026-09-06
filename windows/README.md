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

### パラメーター

| コマンド | 用途 |
|---------|------|
| `Start-Setup.ps1` | 初回セットアップ（Office なし） |
| `Start-Setup.ps1 -IncludeOffice` | 初回セットアップ（Office 含む） |
| `Start-Setup.ps1 -IncludeLocalApps` | 初回セットアップ（非公開ローカルアプリ含む。[詳細](installer/packages/local/README.md)） |
| `Start-Setup.ps1 -Update` | パッケージ更新＋設定再適用 |
| `Start-Setup.ps1 -Update -SyncSecrets` | 更新＋Bitwarden 同期 |
| `Start-Setup.ps1 -SyncSecrets` | Bitwarden → SecretStore 同期のみ |
| `Start-Setup.ps1 -DryRun` | 変更なしで実行内容を確認 |
| `Start-Setup.ps1 -Update -DryRun` | 更新内容を確認 |
| `Start-Setup.ps1 -Prune` | パッケージリストから削除された項目をアンインストール（[詳細](#パッケージ整合prune)） |
| `Start-Setup.ps1 -Prune -Force` | 同上。個別確認をスキップ |
| `Start-Setup.ps1 -Update -Prune` | 更新と同時に整合 |

#### パッケージ整合（prune）

`-Prune` を付けると、`installer/packages/*.ps1` から**削除した**パッケージを実機からアンインストールする。

**仕組み**

- `Install-Apps.ps1` は正常終了時（`-DryRun` 以外）に、その回のパッケージリスト（winget / choco / npm / uv / cargo）を
  `%LOCALAPPDATA%\MyInitSetting\installed-manifest.json` に記録する。
- 次回 `-Prune` を付けて実行すると、マニフェストに載っていて現在のリストに無いものだけを削除候補にする。
- **マニフェストに記録されていないパッケージ（手動導入アプリ、Store アプリ、システムコンポーネント等）には一切触れない。**
- 対象は winget / choco / npm グローバル / uv tools / cargo のみ。PowerShell モジュール・Node.js・`packages/local/`（orca/bartender）は対象外。

**運用フロー**

```powershell
# 1. 不要になったパッケージを installer/packages/choco-packages.ps1 等から削除
# 2. 何が消えるか確認
Start-Setup.ps1 -Prune -DryRun
# 3. 実行（各パッケージごとに y/N を確認）
Start-Setup.ps1 -Prune
```

**注意**

- **初回**（マニフェスト未生成）は記録のみで、削除は行わない。整合が効くのは 2 回目以降。
- profile（Default / Clinic）が前回と変わっている場合は誤削除防止のため prune をスキップする。同じ profile で再実行すること。
- `-Force` は個別確認（`y/N`）を省略して一括削除する。

#### settings サブコマンド

`settings/` 配下のスクリプトを単体で実行できるサブコマンドスイッチ。フルセットアップを経由せず、設定のみ再適用したいときに使う。

| スイッチ | 実行されるスクリプト |
|---------|-----------------|
| `-ServerMode` | `settings/Set-ServerMode.ps1` |
| `-Aliases` | `settings/Set-Aliases.ps1` |
| `-McpServers` | `settings/Set-McpServers.ps1` |
| `-WindowsSettings` | `settings/Set-WindowsSettings.ps1` |
| `-Workspace` | `settings/Set-Workspace.ps1` |

```powershell
# 単体実行
Start-Setup.ps1 -ServerMode
Start-Setup.ps1 -McpServers -DryRun

# 複数まとめて実行
Start-Setup.ps1 -Aliases -McpServers -WindowsSettings

# -Clinic / -DryRun との組み合わせも可
Start-Setup.ps1 -Aliases -Clinic
Start-Setup.ps1 -WindowsSettings -DryRun
```

セットアップ後は PowerShell から `Setup-Windows` コマンドでも呼び出せる:

```powershell
Setup-Windows -Update
Setup-Windows -Update -SyncSecrets
Setup-Windows -DryRun

# settings サブコマンドも同様に使用可能
Setup-Windows -ServerMode
Setup-Windows -McpServers -DryRun
Setup-Windows -Aliases -McpServers -WindowsSettings
```

### 実行スクリプト

`Start-Setup.ps1` が以下のスクリプトを順番に呼び出す:

```
Start-Setup.ps1
├── installer/Install-Chocolatey.ps1      # パッケージマネージャー（初回のみ）
├── installer/Install-Apps.ps1            # アプリ一括インストール／更新
├── installer/Install-Office.ps1          # Microsoft Office（-IncludeOffice 指定時のみ）
├── installer/Initialize-Security.ps1     # Bitwarden → SecretStore（-SyncSecrets 指定時のみ）
├── installer/Setup-Wsl.ps1              # WSL Ubuntu セットアップ／更新
├── settings/Set-Aliases.ps1              # PowerShell プロファイル設定（毎回リセットして書き直し）
├── settings/Set-McpServers.ps1           # MCP サーバー登録（冪等）
├── settings/Set-WindowsSettings.ps1      # Windows 機能・デスクトップ・Docker Desktop（冪等）
├── settings/Set-Workspace.ps1            # ワークスペースディレクトリ作成（初回のみ）
└── settings/Set-ServerMode.ps1           # 24時間サーバー化設定
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

**cargo パッケージ:**
- `bws` — Bitwarden Secrets Manager CLI（winget/choco/npm に公式パッケージが無いため crates.io からソースビルド）。
  `Initialize-Security.ps1` が API キー取得に使う実行時依存でもある

`installer/packages/cargo-packages.ps1` に定義する。`Rustlang.Rustup`（winget リスト）で入る Rust ツールチェーンと、
ネイティブ依存のリンクに必要な MSVC リンカ（choco リストの `visualstudio2022-workload-vctools` で導入）が要る。
`cargo` が PATH に無い場合はスキップして警告のみ出す（rustup / ビルドツール導入直後はシェルを開き直す）。

**非公開ローカルアプリ（`-IncludeLocalApps` 指定時のみ）:**

Chocolatey コミュニティリポジトリに存在しない社内/私物アプリは
`installer/packages/local/<id>/` に `.nuspec` + `tools/chocolateyInstall.ps1` の形で定義する
（バイナリ本体はリポジトリにコミットしない）。`-IncludeLocalApps` を指定した場合のみ、その場で
`choco pack` してローカルフィードからインストールする。詳細は
[`installer/packages/local/README.md`](installer/packages/local/README.md) を参照。

| ID | 内容 |
|----|------|
| `orca` | AI orchestrator CLI。GitHub Releases から都度ダウンロード |
| `bartender` | BarTender ラベル発行ソフト（クリニック用）。インストーラーは別途 `CHOCO_LOCAL_ASSETS` 配下に配置が必要 |

**パッケージ整合（`-Prune`）:**

正常終了時に適用済みパッケージリストを `%LOCALAPPDATA%\MyInitSetting\installed-manifest.json` に記録する。
`-Prune` を付けて実行すると、マニフェストに載っていて現在のリストに無い winget / choco / npm / uv / cargo パッケージを
（インストール済みか確認したうえで、既定では個別 `y/N` 確認、`-Force` で一括）アンインストールする。
マニフェスト非記録のパッケージには触れない。詳細は [パラメーター > パッケージ整合](#パッケージ整合prune) を参照。

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

### `installer/Initialize-Security.ps1` — Bitwarden Secrets Manager → SecretStore

Bitwarden Secrets Manager のプロジェクトに登録したシークレットを PowerShell SecretStore（`LocalStore` Vault）に取り込む。

**フロー:**

```
Bitwarden Secrets Manager (クラウド)
  └─ bws secret list（アクセストークンは環境変数 or 対話貼り付け・非保存）
      └─ SM secret の key → シークレット名、value → 値
          └─ SecretStore (LocalStore) に保存
              └─ Load-SecretEnvironment → 環境変数として利用可能
```

SM secret は素の key/value を持つため、旧 `bw` 方式の「`login.password` → `notes` → フィールド名マッチ」の優先順位ロジックは廃止。
key が環境変数名として不正なもの（英数字・アンダースコア以外を含む等）は警告してスキップする。

**アクセストークン:**
- 環境変数 `BWS_ACCESS_TOKEN` があればそれを使用（CI 向け）。無ければ非表示プロンプトで入力。
- スクリプトプロセス内のみで使用し、プロンプト入力分は終了時に破棄。平文ファイル・恒久環境変数・SecretStore には保存しない。
- トークンはマシンアカウント権限＝指定プロジェクトの**読み取りのみ**。個人 Vault（ログイン・TOTP・カード等）には一切アクセスしない。
- 対象プロジェクトを絞る場合は環境変数 `BWS_PROJECT`（名前 or GUID）または `-BwsProject`。未指定ならマシンアカウントが読める全シークレット。

**SecretStore の設定:**
- `Authentication None` — パスワード不要でアクセス可能
- `Interaction None` — 対話プロンプトを抑制

**事前準備（一度きり・手動）:** 旧 `api_keys` Vault フォルダのアイテムを Secrets Manager プロジェクトへ移行する
（各アイテムの名前を secret の key、値を secret の value にする。key は環境変数として有効な識別子にすること）。

セットアップ後は PowerShell プロファイルから `Sync-ApiKeys` コマンドで再同期できる（アクセストークンの入力を求められる）。

---

### `settings/Set-Workspace.ps1` — ワークスペース設定

`$HOME\workspace` ディレクトリを作成し、`$workspace` 変数を PowerShell プロファイルに追記する。

---

### `settings/Set-Aliases.ps1` — PowerShell プロファイル設定

PowerShell プロファイル（`$PROFILE`）をリセットしてから、エイリアスと関数を書き込む。実行時はまず既存プロファイルをバックアップして空ファイルに戻し、その後で内容を書き出す。

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

**API キー・セットアップ管理関数:**

| 関数 | 説明 |
|------|------|
| `Load-SecretEnvironment` | SecretStore のシークレットを環境変数に展開。プロファイル読み込み時に自動実行 |
| `Sync-ApiKeys` | `Initialize-Security.ps1` を実行し Bitwarden Secrets Manager から最新キーを取得・反映（アクセストークンの入力を求められる） |
| `Setup-Windows` | `Start-Setup.ps1` のエイリアス。全パラメーターを透過的に渡す |
| `Set-ServerMode` | `settings/Set-ServerMode.ps1` のエイリアス。`-DryRun` を透過的に渡す |
| `servermode` / `Get-ServerMode` | `Set-ServerMode.ps1` で設定したサーバー化設定の現在状態をチェックリスト表示（読み取りのみ） |

**リセット方式:** 実行のたびにプロファイルを空にしてから丸ごと書き直す。マーカー行はセクションの目印として残るが、マーカー外のユーザーカスタマイズも含めて破棄される。実行前のプロファイルはバックアップされ、`.bak` / `.bak.2` / `.bak.3` の3世代を保持する。

**tailnet 限定ポート公開:** `Enable-TailnetPort` / `Get-TailnetPorts` の使い方は
[`../TAILNET-PORTS.md`](../TAILNET-PORTS.md) を参照。

---

### `settings/Set-WindowsSettings.ps1` — Windows 設定まとめ

以下の3つの設定を一括で行う。管理者権限が必要（未昇格の場合は自動でダイアログ表示）。

**Windows Sandbox の有効化:**
- `Containers-DisposableClientVM` 機能を有効化。再起動が必要な場合は通知する。

**デスクトップ・タスクバーのクリーンアップ:**
- デスクトップとタスクバーの `.lnk` / `.url` ショートカットを削除。ゴミ箱は保持する。

**Docker Desktop WSL 連携:**
- `%APPDATA%\Docker\settings-store.json` を編集し、Ubuntu の WSL 統合を有効化する。設定変更後は Docker Desktop の再起動が必要。

```powershell
& .\settings\Set-WindowsSettings.ps1           # 実行
& .\settings\Set-WindowsSettings.ps1 -DryRun   # 確認のみ
```

---

### `settings/Set-McpServers.ps1` — 追加 MCP サーバー登録

`settings/.mcp.json` に定義した MCP サーバーを `~/.claude.json` にマージする。`jq` を使って既存の設定を壊さずに `mcpServers` キーを上書きする。

```powershell
# カスタム MCP サーバーを追加する場合
# settings/.mcp.json を編集してから実行
& .\settings\Set-McpServers.ps1
```

---

### `settings/Set-ServerMode.ps1` — 24時間サーバー化設定

Windows を常時稼働サーバーとして運用するための設定を一括で行う。管理者権限が必要。

**設定内容:**

| ステップ | 内容 |
|---------|------|
| 1 | スリープ・休止状態・モニタータイムアウトを無効化（AC/DC 両方） |
| 2 | ノートPC の蓋を閉じても何もしない設定（AC/DC 両方） |
| 3 | 高パフォーマンス電源プランに変更 |
| 4 | 自動ログイン設定（オプション・デフォルト無効） |
| 5 | Windows Update を無効化（グループポリシー＋サービス＋スケジュールタスク） |
| 6 | OpenSSH Server (sshd) と Tailscale を自動起動に設定 |

**自動ログインを有効にする場合:** スクリプト冒頭の変数を編集する。

```powershell
$AutoLoginEnabled  = $true      # 有効化
$AutoLoginUsername = "lesen"    # ユーザー名
$AutoLoginPassword = "pass"     # パスワード（平文注意）
```

```powershell
# 直接実行
& .\settings\Set-ServerMode.ps1
& .\settings\Set-ServerMode.ps1 -DryRun   # 確認のみ

# Start-Setup.ps1 経由
Start-Setup.ps1 -ServerMode
Start-Setup.ps1 -ServerMode -DryRun
Setup-Windows   -ServerMode

# プロファイル関数（Set-Aliases.ps1 適用後）
Set-ServerMode
Set-ServerMode -DryRun
```

**設定状態の確認:** `Set-Aliases.ps1` が定義する `servermode`（= `Get-ServerMode`）で、
電源プラン・スリープ・蓋閉じ・Windows Update・sshd・Tailscale の現在状態を期待値と
突き合わせて表示する。変更は行わない。

```powershell
servermode
```
