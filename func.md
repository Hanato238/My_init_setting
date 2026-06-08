# PowerShell `claude` 関数 原案

`$PROFILE` に追加する `claude` 関数。3つのモードを自動判定する。

## 動作フロー

```
claude [args]
  │
  ├─ -host フラグあり
  │     └─ ホストの claude バイナリを直接実行
  │
  ├─ .devcontainer/ がカレントディレクトリに存在する
  │     ├─ clinic-dev コンテナが未起動 → docker compose up -d
  │     │                              → start.sh 実行（サーバー起動 + ngrok URL 設定）
  │     └─ docker exec -it clinic-dev ccmux [args]
  │
  └─ .devcontainer/ が存在しない
        └─ sbx run claude [args]
```

## 関数コード

```powershell
function claude {
    param(
        [switch]$host,
        [Parameter(ValueFromRemainingArguments = $true)]
        [string[]]$Rest
    )

    # ③ -host: ホストにインストールされた claude を直接実行
    if ($host) {
        $exe = Get-Command claude -CommandType Application -ErrorAction SilentlyContinue |
               Select-Object -First 1 -ExpandProperty Source
        if (-not $exe) { Write-Error 'ホストに claude が見つかりません'; return }
        & $exe @Rest
        return
    }

    # ① .devcontainer/ あり: コンテナ起動 → ccmux
    if (Test-Path '.devcontainer' -PathType Container) {
        $compose   = '.devcontainer\docker-compose.yml'
        $container = 'clinic-dev'

        $status = docker inspect --format '{{.State.Status}}' $container 2>$null
        if ($status -ne 'running') {
            Write-Host 'コンテナ起動中...' -ForegroundColor Cyan
            docker compose -f $compose up -d
            if ($LASTEXITCODE -ne 0) { Write-Error '起動失敗'; return }

            $ready = $false
            for ($i = 0; $i -lt 30; $i++) {
                $status = docker inspect --format '{{.State.Status}}' $container 2>$null
                if ($status -eq 'running') { $ready = $true; break }
                Start-Sleep -Seconds 2
            }
            if (-not $ready) {
                Write-Error "$container が起動しませんでした"
                docker compose -f $compose logs node
                return
            }

            docker exec $container bash /workspace/.devcontainer/start.sh
        } else {
            Write-Host "コンテナ起動済み ($container)" -ForegroundColor Green
        }

        docker exec -it $container ccmux @Rest
        return
    }

    # ② .devcontainer/ なし: sbx run claude
    Write-Host '.devcontainer なし → sbx run claude' -ForegroundColor Yellow
    sbx run claude @Rest
}
```

## $PROFILE への追加手順

```powershell
# プロファイルを開く
code $PROFILE   # または notepad $PROFILE

# 上の関数を貼り付けて保存後、リロード
. $PROFILE
```

## 使い方

| コマンド | 動作 |
|---|---|
| `claude` | `.devcontainer/` があればコンテナ起動 → ccmux、なければ sbx run claude |
| `claude -host` | ホストの claude バイナリを直接実行 |
| `claude -host --version` | ホスト claude にフラグを渡す |

## 備考

- `-host` は PowerShell 自動変数 `$Host` と名前が衝突する場合がある。
  動作しない場合は `-AsHost` にリネーム（`$host` → `$AsHost` を全置換）。
- コンテナ内では `claude` ではなく `ccmux` を起動する（複数セッション管理のため）。
- compose ファイルパス・コンテナ名は `clinic-vectra` 専用の固定値。
  他プロジェクトへの流用時は `$compose` / `$container` を変更すること。
