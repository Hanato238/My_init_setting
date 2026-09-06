# verify/ — bws 環境変数フローの検証

`secrets.list` → `bws-login` → コンテナ内 `~/.secrets` の受け渡しを点検する使い捨てツール。
テンプレートを新プロジェクトへコピーするときは `.devcontainer/` だけで足り、この `verify/` は不要。

## 前提

- `claude_container_template` コンテナが起動している（`claude` で起動）
- bws マシンアカウントのアクセストークン
- （任意）検証用シークレットを bws に用意（下記）

## 使い方（ホスト PowerShell）

```powershell
cd claude_container_template

# 1. ホスト側だけ点検（コンテナに触れない）
powershell -ExecutionPolicy Bypass -File verify\Verify-BwsFlow.ps1 -HostOnly

# 2. フル検証：bws-login 実行 → コンテナ内の ~/.secrets と各名前の解決状況
powershell -ExecutionPolicy Bypass -File verify\Verify-BwsFlow.ps1

# 3. bws-login を再実行せず、今のコンテナ状態だけ見る
powershell -ExecutionPolicy Bypass -File verify\Verify-BwsFlow.ps1 -SkipLogin

# 4. 「ホスト env があれば bws より優先」ロジックの確認
#    先に secrets.list へ  VERIFY_HOST_VAR  を追記しておく
powershell -ExecutionPolicy Bypass -File verify\Verify-BwsFlow.ps1 -SimulateHostVar
```

トークンを引数で渡す場合は `-Token "0.xxxx..."`（省略時は `bws-login.ps1` の
通常の解決順：環境変数 → ホストのファイル → プロンプト）。

## 検証用シークレットの作り方

```bash
# コンテナ内 or ホストの bws で
bws project list                                   # project-id を確認
bws secret create VERIFY_BWS_VAR hello-from-bws <project-id>
```

そのうえで `secrets.list` に次の 2 行を足してコメントを外す：

```
VERIFY_BWS_VAR
VERIFY_HOST_VAR
```

期待結果：

| 名前 | SOURCE | 意味 |
|------|--------|------|
| `VERIFY_BWS_VAR` | `bws->file` | bws から取得し `~/.secrets` に書かれた |
| `VERIFY_HOST_VAR` | `host/env`（`-SimulateHostVar` 時）| env にあるので `~/.secrets` に書かれない＝ホスト優先が効いている |
| `VERIFY_HOST_VAR` | `MISSING`（通常時）| bws にも env にも無いので skip |

## コンテナ内で直接

```bash
bash /workspace/verify/verify-in-container.sh
# 別のリストを指定:
bash /workspace/verify/verify-in-container.sh /path/to/secrets.list
```

## 後片付け

```bash
bws secret list <project-id>            # id を確認
bws secret delete <secret-id>
```

`secrets.list` に足した `VERIFY_*` 行を消し、`~/.secrets` から該当行を削除
（または `bash .devcontainer/load-secrets.sh` を再実行）。
