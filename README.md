# My_init_setting

Windows・WSL Ubuntu の開発環境を一括セットアップするためのスクリプト集。

## ディレクトリ構成

```
My_init_setting/
├── windows/          # Windows 11 用 PowerShell スクリプト
├── ubuntu/           # WSL Ubuntu 用 Bash スクリプト
│   └── remote-dev/   # GCP VM リモート開発環境（Tailscale + Orca）の作成スクリプト
└── android/termux/   # Android Termux 用 Bash スクリプト
```

## クイックスタート

### Windows 11 の初期セットアップ

PowerShell を**管理者として**起動し、以下を実行:

```powershell
iex (iwr "https://raw.githubusercontent.com/hanato238/My_init_setting/main/windows/Start-Setup.ps1")
```

詳細は [`windows/README.md`](windows/README.md) を参照。

### WSL Ubuntu の初期セットアップ

WSL Ubuntu 上で以下を順番に実行:

```bash
bash ubuntu/install_apps.sh
bash ubuntu/setup_workspace.sh
bash ubuntu/setup_aliases.sh
bash ubuntu/initialize_security.sh
```

詳細は [`ubuntu/README.md`](ubuntu/README.md) を参照。

## 関連ドキュメント

- [`TAILNET-PORTS.md`](TAILNET-PORTS.md) — tailnet 限定でポートを公開するヘルパー（Windows/Ubuntu 共通）

## 設計方針

- **冪等性**: 各スクリプトは何度実行しても安全（既存設定を二重登録しない）
- **秘密情報管理**: API キーは Bitwarden Secrets Manager を唯一の正としてローカルに配布
  - 取得は `bws`（Secrets Manager CLI）+ マシンアカウントのアクセストークン。トークンは実行時に環境変数か対話貼り付けで渡し、平文ファイル・恒久環境変数・SecretStore のいずれにも保存しない
  - Windows: PowerShell SecretStore (`LocalStore` Vault)
  - Ubuntu / Termux: `~/.secrets` ファイル（chmod 600）
  - devcontainer: `.devcontainer/secrets.list` に列挙した名前だけを取り込む。ホスト env（`docker-compose.yml` の `environment:`）を優先し、無ければ bws から補完して `~/.secrets`（chmod 600）へ。反映は `.devcontainer/load-secrets.sh`（`bws-login` 実行時に自動）
- **MCP サーバー**: Claude Code・Gemini CLI に共通の MCP サーバー群を登録
