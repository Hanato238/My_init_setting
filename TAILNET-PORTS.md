# Tailnet 限定ポート公開ヘルパー

特定のポートを **tailnet（Tailscale ネットワーク）内からのみ** 到達可能にするためのヘルパー関数・エイリアス集。
Windows と Ubuntu（remote-dev VM）の両方に同等の機能を用意している。

tailnet の CIDR（`100.64.0.0/10`）はハードコードせず、実行時にそのマシンの Tailscale IP から自動検出する
（Tailscale は常にこの CGNAT レンジから割り当てるため、第1・第2オクテットから `/10` ネットワークアドレスを逆算できる）。

| プラットフォーム | 実装 | ソース |
|---|---|---|
| Windows | Windows Firewall (`New-NetFirewallRule`) | [`windows/settings/Set-Aliases.ps1`](windows/settings/Set-Aliases.ps1) |
| Ubuntu (remote-dev VM) | `ufw` | [`ubuntu/remote-dev/setup.sh`](ubuntu/remote-dev/setup.sh) |

---

## Windows

`Set-Aliases.ps1` 実行後（＝PowerShell プロファイル読み込み後）に使える関数。

### `Enable-TailnetPort`

```powershell
Enable-TailnetPort -Port 8080
Enable-TailnetPort -Port 8080 -Protocol UDP
```

- `-Port`（必須）: 開放するローカルポート（1〜65535）
- `-Protocol`: `TCP`（既定）または `UDP`
- 現在の `tailscale ip -4` から tailnet CIDR を自動検出し、`Allow <Protocol> <Port> (Tailnet only)` という
  `DisplayName` の Inbound 許可ルールを作成する
- Tailscale が起動していない（IP が取得できない）場合はエラーを出して何もしない

### `Get-TailnetPorts`

```powershell
Get-TailnetPorts
```

`Enable-TailnetPort` で作成したルール（`DisplayName` が `Allow * (Tailnet only)` に一致するもの）を一覧表示する。

```
DisplayName                       Protocol LocalPort RemoteAddress    Direction Enabled
-----------                       -------- --------- -------------    --------- -------
Allow TCP 8080 (Tailnet only)     TCP      8080      100.64.0.0/10    Inbound   True
```

### 前提条件

- Tailscale がインストール・起動済みであること（`tailscale ip -4` が値を返すこと）
- `Set-Aliases.ps1` を実行してプロファイルに反映済みであること

---

## Ubuntu（remote-dev VM）

`ubuntu/remote-dev/setup.sh` が `/etc/profile.d/90-remote-dev-aliases.sh` を設置し、対話ログインする
全ユーザーのシェルに以下の関数を追加する（Windows 側の同名関数の移植）。

### `enable-tailnet-port`

```bash
enable-tailnet-port 8080
enable-tailnet-port 8080 udp
```

- 第1引数（必須）: ポート番号
- 第2引数: `tcp`（既定）または `udp`
- `tailscale ip -4` から tailnet CIDR を自動検出し、`ufw allow from <CIDR> to any port <port> proto <proto>
  comment 'tailnet-only'` を実行する
- `ufw` 未インストール、または Tailscale IP が取得できない場合はエラーを出して何もしない

### `get-tailnet-ports`

```bash
get-tailnet-ports
```

`enable-tailnet-port` で追加したルール（コメントが `tailnet-only` のもの）を `ufw status numbered` から抽出して表示する。

### ufw の自動有効化について

`setup.sh` は初回実行時に `ufw` を自動で `enable` する。SSH ロックアウトを避けるため、必ず以下の順序で行う:

1. `22/tcp`（SSH。GCE OS Login 用。`eth0` 経由でここに来る）を許可
2. `tailscale0` インターフェース全体を許可（Tailscale SSH や Orca サーバー(6768番)はこちらを通る）
3. `default deny incoming` に設定
4. `ufw enable`

既に `ufw` が active な場合は何もしない（冪等）。個別ポートの追加はこの初期設定では行わず、
必要になった時点で `enable-tailnet-port` を都度実行する運用。

---

## 関連: `Install-Apps.ps1` のインストール済みスキップ

エイリアスではないが、同じセッションで `windows/installer/Install-Apps.ps1` にも変更を加えている。
Chrome・Google Drive のように winget/choco 経由の管理と実体がずれているアプリで再インストールが
走ってしまう問題への対処として、インストール前に既存チェックを追加した:

- **winget**: `winget list -e --id <pkg>` の終了コードが `0`（＝見つかった）ならスキップ
- **choco**: `choco list --local-only -r` の出力からインストール済み ID を集め、対象リストから除外

`-Update` 指定時（アップグレード実行時）はこのスキップを行わない。

---

## 既知の落とし穴（トラブルシューティング）

`Enable-TailnetPort` 実装時に実際に踏んだ2つのPowerShell特有のハマりどころ。今後似た関数を追加する際の注意点として記録。

### 1. 文字列展開中の `$var.0` はメンバーアクセスと誤解釈される

```powershell
# NG: ".0" が "0" というプロパティへのアクセスだと解釈され
#     "Missing property name after reference operator" になる
"$maskedSecondOctet.0.0/10"
"$($maskedSecondOctet).0.0/10"   # $() で囲んでも同じ問題が起きる

# OK: -f 演算子でフォーマットする
"{0}.0.0/10" -f $maskedSecondOctet
```

`$var.` や `$(expr).` の直後に数字が続くと、PowerShell はそれを「プロパティ `0` へのアクセス」として
パースしようとして失敗する。曖昧さを避けるには `-f` フォーマット演算子か文字列連結 (`+`) を使う。

### 2. プロファイルは BOM 付き UTF-8 で書き出す

`Set-Aliases.ps1` が生成する `$PROFILE` に日本語（コメントやエラーメッセージ）を含む場合、
BOM なし UTF-8 で書き出すと Windows PowerShell 5.1 がシステムの ANSI コードページ（日本語環境では
Shift-JIS）で読み込もうとし、文字化けからパースエラーが連鎖することがある。
`[System.IO.File]::WriteAllText` に渡すエンコーディングは
`New-Object System.Text.UTF8Encoding $true`（BOM 付き）にすること。
