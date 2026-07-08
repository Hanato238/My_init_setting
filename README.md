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

## 設計方針

- **冪等性**: 各スクリプトは何度実行しても安全（既存設定を二重登録しない）
- **秘密情報管理**: API キーは Bitwarden を唯一の正としてローカルに配布
  - Windows: PowerShell SecretStore (`LocalStore` Vault)
  - Ubuntu: `~/.secrets` ファイル（chmod 600）
- **MCP サーバー**: Claude Code・Gemini CLI に共通の MCP サーバー群を登録
