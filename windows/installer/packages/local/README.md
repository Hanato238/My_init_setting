# packages/local/ — 内部・非公開 Chocolatey パッケージ

Chocolatey コミュニティリポジトリに公開されていない、社内/私物アプリのパッケージ定義を置く場所。
サブフォルダごとに `<id>.nuspec` + `tools/chocolateyInstall.ps1` + `tools/chocolateyUninstall.ps1`
のみを置く（バイナリ本体はコミットしない）。

## インストール方法

`Install-Apps.ps1 -IncludeLocalApps` を指定すると、このフォルダ配下の各パッケージを
`choco pack` でその場ビルドし、一時ローカルフィード（`$env:TEMP\choco-local-feed`）から
`choco install` する。デフォルト（`-IncludeLocalApps` なし）ではスキップされる。

```powershell
Start-Setup.ps1 -IncludeLocalApps
Start-Setup.ps1 -Update -IncludeLocalApps
& .\installer\Install-Apps.ps1 -IncludeLocalApps -DryRun   # 確認のみ
```

## パッケージ一覧

| ID | 内容 | インストーラーの入手方法 |
|----|------|------------------------|
| `orca` | AI orchestrator CLI ([stablyai/orca](https://github.com/stablyai/orca)) | GitHub Releases から都度ダウンロード（`chocolateyInstall.ps1` 内にURL・checksumを記載） |
| `bartender` | BarTender ラベル発行ソフト + Seagull プリンタドライバ（クリニック用） | 別途配置が必要（下記参照） |

## bartender: インストーラーの配置

`bartender` は Seagull Scientific のライセンス製品で、公開URLからは取得できない。
このパッケージは `.nuspec` にインストーラーを同梱せず、インストール実行時に外部の
アセット置き場を探しにいく（`tools/chocolateyInstall.ps1` の `Resolve-BartenderAsset` 参照）。

対象マシンの以下のパスに事前にファイルを配置しておくこと（`CHOCO_LOCAL_ASSETS` 環境変数で
ルートを変更可能。未設定時は `C:\ChocoLocalAssets`）:

```
%CHOCO_LOCAL_ASSETS%\Bartender\BarTender\BarTender_Label Design Software.exe
%CHOCO_LOCAL_ASSETS%\Bartender\Driver\BeeprtPrinter_2024.2.exe
%CHOCO_LOCAL_ASSETS%\Bartender\Manual\取扱説明書_Ver202505.pdf
```

ファイルが見つからない場合、インストールはエラーで停止し、探索したパスをメッセージに表示する。
`--params "/SkipDriver /SkipManual"` でドライバー・マニュアルの手順のみスキップすることも可能
（BarTender 本体は `/SkipBarTender` では省略できない設計ではなく、同様に `/SkipBarTender` で省略可）。

このリポジトリのリポジトリルート直下 `my_apps/` は元アセットの置き場として使われていたが
`.gitignore` 済みであり、コミットされることはない。恒久的な配置場所としては
`CHOCO_LOCAL_ASSETS` を明示的に設定することを推奨する。
