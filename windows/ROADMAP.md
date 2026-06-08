# Windows セットアップ ROADMAP — Update 機能追加

## 決定済み設計方針

| 項目 | 決定 |
|------|------|
| エントリーポイント | `-Update` スイッチ（`-Mode` パラメーターは不採用） |
| winget 更新スコープ | リスト内パッケージのみ（`--all` は不採用） |
| Set-Aliases 冪等性 | マーカーセクション方式 |
| Bitwarden 同期 | `-SyncSecrets` 独立スイッチ、`Sync-ApiKeys` はそのエイリアス |
| Office | Update 時は常にスキップ、初回インストールは `-IncludeOffice` で明示制御 |
| 個別スクリプト制御 | 不要（直接呼び出しで代替） |
| ログファイル | 不要（呼び出し側でリダイレクト） |
| 再起動後再開 | 不要（メッセージ表示のみ） |
| npm 更新 | Install/Update 共に `npm install -g`（冪等） |
| 実行サマリー | 必要 |
| Node.js バージョン | 固定（22）、Update 時も上げない |

---

## 完成形の呼び出しインターフェース

```powershell
# 初回セットアップ（Office なし）
Start-Setup.ps1

# 初回セットアップ（Office 含む）
Start-Setup.ps1 -IncludeOffice

# 更新（パッケージ + 設定の再適用）
Start-Setup.ps1 -Update

# 更新 + Bitwarden 同期
Start-Setup.ps1 -Update -SyncSecrets

# Bitwarden 同期のみ（プロファイルの Sync-ApiKeys コマンドと同等）
Start-Setup.ps1 -SyncSecrets

# 内容確認のみ（変更なし）
Start-Setup.ps1 -DryRun
Start-Setup.ps1 -Update -DryRun
```

---

## フェーズ 1 — 基盤整備（最優先）

### 1-A: `Start-Setup.ps1` パラメーター追加と `-DryRun` 伝播

```powershell
param(
    [switch]$Update,
    [switch]$SyncSecrets,
    [switch]$IncludeOffice,
    [switch]$DryRun
)
```

**Install 時の実行スクリプト順:**

```
Install-Chocolatey.ps1        # 常に実行
Install-Apps.ps1              # 常に実行
Install-Office.ps1            # -IncludeOffice 指定時のみ
Initialize-Security.ps1       # -SyncSecrets 指定時のみ
Setup-Wsl.ps1                 # 常に実行
Set-Aliases.ps1               # 常に実行（マーカー方式で冪等）
Set-McpServers.ps1            # 常に実行（すでに冪等）
Set-WindowsSettings.ps1       # 常に実行（すでに冪等）
Set-Workspace.ps1             # 常に実行（すでに冪等）
```

**Update 時の実行スクリプト順:**

```
Install-Apps.ps1 -Update      # winget/choco/npm 更新
Initialize-Security.ps1       # -SyncSecrets 指定時のみ
Setup-Wsl.ps1 -Update         # WSL 内パッケージ更新
Set-Aliases.ps1               # マーカー内を更新
Set-McpServers.ps1            # MCP 設定を再適用
Set-WindowsSettings.ps1       # 設定を再適用
```

**サマリー出力（共通）:**

```powershell
$results = @()  # @{ Script = "Install-Apps.ps1"; Status = "OK"|"WARN"|"ERR"; Message = "..." }

# 実行後に表示
Write-Host "`n=== Setup Summary ===" -ForegroundColor Cyan
foreach ($r in $results) {
    $color = switch ($r.Status) { "OK" { "Green" } "WARN" { "Yellow" } "ERR" { "Red" } }
    Write-Host "[$($r.Status)]".PadRight(7) "$($r.Script)$(if ($r.Message) { "  — $($r.Message)" })" -ForegroundColor $color
}
```

### 1-B: `Set-Workspace.ps1` バグ修正

34 行目: `$setLocationLine` が未定義のまま参照されている。変数定義を追加する。

---

## フェーズ 2 — 各スクリプトの対応

### 2-A: `Install-Apps.ps1` — `-Update` スイッチ追加

```powershell
param([switch]$Update, [switch]$DryRun)
```

| フェーズ | Install（`-Update` なし） | Update（`-Update` あり） |
|---------|--------------------------|--------------------------|
| winget | `winget install -e --id $pkg` | `winget upgrade -e --id $pkg` |
| Chocolatey | `choco install @chocoPackages -y` | `choco upgrade @chocoPackages -y` |
| npm | `npm install -g @npmPackages` | `npm install -g @npmPackages`（同じ） |
| PSModules | `Install-Module -Force` | `Update-Module` |
| Node.js | `nvm install 22 && nvm use 22` | `nvm use 22`（バージョン固定） |

### 2-B: `Initialize-Security.ps1` — `-DryRun` 追加

```powershell
param([switch]$DryRun)
```

- `DryRun` 時: Bitwarden からフェッチしたシークレット名の一覧を表示するだけ（SecretStore への書き込みなし）

### 2-C: `Install-Office.ps1` — `-DryRun` 追加、Update 時スキップ

```powershell
param([switch]$DryRun)
```

- Update 時: `Start-Setup.ps1` がそもそも呼び出さない
- Install 時でも `-IncludeOffice` がない場合はスキップ（サマリーに WARN 表示）
- `-DryRun`: 実行コマンドを表示するだけ

### 2-D: `Set-Aliases.ps1` — マーカー方式による冪等化

**プロファイル構造:**

```powershell
# === MANAGED BY Set-Aliases.ps1 — DO NOT EDIT BETWEEN THESE MARKERS ===
Set-Alias -Name "chrome" -Value "..."
# ... (スクリプト管理のエイリアス・関数群) ...
function Sync-ApiKeys {
    & "$HOME\workspace\My_init_setting\windows\Start-Setup.ps1" -Update -SyncSecrets
}
# === END MANAGED SECTION ===

# ↑ 以下はユーザーの自由領域（スクリプトは触れない）
```

**更新ロジック:**
- マーカーが存在する → セクション内のみ正規表現で置換
- マーカーがない（初回 or 既存プロファイル） → 末尾に追記
- バックアップは最新 3 世代のみ保持（`$profilePath.bak1/2/3`）

`Sync-ApiKeys` の実体を `Initialize-Security.ps1` の直接呼び出しから `Start-Setup.ps1 -Update -SyncSecrets` に変更する。

### 2-E: `Setup-Wsl.ps1` — `-Update` スイッチ追加

```powershell
param([string]$Category = "all", [switch]$Update, [switch]$DryRun)
```

- `-Update` 指定時: `ubuntu/setup.sh update` を呼び出す
- `ubuntu/setup.sh` 側の `update` カテゴリ対応は ubuntu 側の作業

---

## フェーズ 3 — UX 改善

### 3-A: 実行サマリー（フェーズ 1-A に含む）

フェーズ 1-A の `Start-Setup.ps1` 実装時に同時対応。

---

## スコープ外（変更なし）

| スクリプト | 理由 |
|-----------|------|
| `Set-McpServers.ps1` | すでに冪等（マージ動作）、`-DryRun` 対応済み |
| `Set-WindowsSettings.ps1` | すでに冪等、`-DryRun` 対応済み |
| `Install-Chocolatey.ps1` | 有無チェック付きインストールのみで十分 |
| Node.js バージョン | 固定（22）、Update 時も自動アップグレードしない |
| Office 更新 | Windows Update / Microsoft 365 自動更新に委任 |
| ログファイル | 呼び出し側 `*> log.txt` で代替 |
| 再起動後再開 | タスクスケジューラ登録は複雑すぎ、メッセージ案内で十分 |

---

## 実装チェックリスト

### フェーズ 1（必須）
- [ ] `Start-Setup.ps1`: `-Update` / `-SyncSecrets` / `-IncludeOffice` / `-DryRun` パラメーター追加
- [ ] `Start-Setup.ps1`: `-DryRun` を全子スクリプトに伝播
- [ ] `Start-Setup.ps1`: サマリー表示（`try/catch` で結果収集）
- [ ] `Set-Workspace.ps1`: `$setLocationLine` バグ修正

### フェーズ 2
- [ ] `Install-Apps.ps1`: `-Update` スイッチ追加（winget/choco/Node.js の挙動分岐）
- [ ] `Initialize-Security.ps1`: `-DryRun` スイッチ追加
- [ ] `Install-Office.ps1`: `-DryRun` スイッチ追加
- [ ] `Set-Aliases.ps1`: マーカー方式に変更、`Sync-ApiKeys` の実体を更新
- [ ] `Setup-Wsl.ps1`: `-Update` スイッチ追加
