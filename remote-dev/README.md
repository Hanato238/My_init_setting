# remote-dev/ — GCP VM リモート開発環境セットアップ

GCP上にUbuntu VMを作成し、Tailscale + Orca headless server でリモート開発できるようにするための構成一式。VM上のソフトウェアセットアップ自体は [`ubuntu/setup.sh remote-dev`](../ubuntu/README.md) が行う。ここにあるのはその前段（VMの作成）を担うラッパースクリプトと設定。

## 構成

```
remote-dev/
├── config/
│   └── vm-config.json   # VM作成パラメータ（プロジェクトID、ゾーン等）
├── Create-Vm.ps1         # gcloudでVMを作成するラッパースクリプト（Windows/PowerShell）
└── README.md
```

## 使い方

### 1. 事前準備

- Windows側に gcloud SDK をインストール（`windows/installer/packages/choco-packages.ps1` の `gcloudsdk`、または `choco install gcloudsdk`）
- `gcloud init` と `gcloud auth login` でログイン
- `config/vm-config.json` を編集し、`projectId` をプレースホルダーから実際の値に置き換える

### 2. VM作成

```powershell
cd remote-dev
.\Create-Vm.ps1                                          # 作成
.\Create-Vm.ps1 -DryRun                                   # 実行されるgcloudコマンドの確認のみ
.\Create-Vm.ps1 -ConfigPath .\config\other-vm-config.json  # 別設定ファイルを使う場合
```

### 3. VM上でのセットアップ（手動）

```bash
gcloud compute ssh <vmName> --zone=<zone> --project=<projectId>
git clone https://github.com/Hanato238/My_init_setting.git
bash My_init_setting/ubuntu/setup.sh remote-dev
```

以降（Tailscale認証・exit node承認・Orcaサービス起動）は `ubuntu/setup.sh remote-dev` 実行後に表示される案内に従う。

## vm-config.json の項目

| キー | 説明 | 例 |
|------|------|-----|
| `projectId` | GCPプロジェクトID | `my-project-123456` |
| `zone` | 作成するゾーン | `asia-northeast1-a` |
| `vmName` | インスタンス名 | `remote-dev-vm` |
| `machineType` | マシンタイプ | `e2-medium` |
| `imageFamily` | OSイメージファミリー | `ubuntu-2204-lts` |
| `imageProject` | イメージ提供元プロジェクト | `ubuntu-os-cloud` |
| `diskSizeGb` | ブートディスクサイズ(GB)。省略時 `30` | `30` |
| `diskType` | ブートディスクタイプ。省略時 `pd-balanced` | `pd-balanced` |
| `enableIpForward` | IP forwardingを有効化するか（exit node化に必須）。**作成後は変更不可** | `true` |
| `networkTags` | ネットワークタグ（ファイアウォールルール等で利用、省略可） | `["remote-dev"]` |

`vm-config.json` は複数環境用にコピーして使ってもよい（例: `config/staging-vm-config.json`）。その場合は `Create-Vm.ps1 -ConfigPath` で明示的に指定する。
