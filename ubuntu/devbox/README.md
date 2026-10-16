# devbox/ — ローカルDocker開発コンテナ（tmux + Claude Code + Antigravity CLI）

WSL上のDocker Engineで、tmux・Claude Code・Antigravity CLI（`agy`）を入れたコンテナを立て、
このリポジトリ（`My_init_setting`）をマウントして作業するための試験的プロジェクト。
`remote-dev/`・`remote-agy/`・`life-os/`と違い、GCP VMではなく**ローカルのDocker Engine**上で動く。

## 構成

```
devbox/
├── Dockerfile   # tmux + Node(nvm) + Claude Code + Antigravity CLI を入れたイメージ定義
├── setup.sh     # エントリーポイント。イメージbuild + コンテナ起動（冪等）
└── README.md
```

## 使い方

```bash
bash devbox/setup.sh
```

初回はイメージのbuildとコンテナの作成が行われる。2回目以降は既存のイメージ/コンテナを
再利用する（冪等）。完了後、以下でコンテナ内のtmuxにアタッチする:

```bash
docker exec -it devbox tmux new -A -s main
```

コンテナ内では `/workspace/My_init_setting` にこのリポジトリがバインドマウントされている
（ホスト側と同じファイルを直接編集する。コピーではない）。

## 永続化の範囲（セッション引継ぎについて）

このプロジェクトは「WSL再起動でセッションは消えるか」という検討から生まれたもので、
前提を明示的に切り分けている:

| 要素 | 永続化方法 | WSL再起動で消えるか |
|------|-----------|------------------|
| プロジェクトのファイル | ホストのバインドマウント（`-v $PROJECT_ROOT:/workspace/...`） | 消えない |
| `$HOME`（Claude Codeの会話履歴・agyの設定など） | 名前付きボリューム `devbox-home` | 消えない（`docker volume rm`しない限り） |
| コンテナ自体 | `--rm`なしで起動。停止後は`docker start`で復帰 | 消えない（削除しない限り） |
| tmuxの生きているセッション（スクロールバック・実行中シェル） | なし（プロセスなので原理的に不可） | **消える** |

つまりWSL再起動後は:
1. `bash devbox/setup.sh` を再実行（Docker Engine起動確認 + コンテナ起動、冪等）
2. `docker exec -it devbox tmux new -A -s main` で新しいtmuxセッションにアタッチ
3. コンテナ内で `claude --continue`（または `claude --resume`）を叩くと、**会話の内容**は
   `devbox-home`ボリュームから復元される

tmuxの画面そのものは毎回作り直しだが、Claude Codeの対話内容はツール側のresume機能で
復元される、という前提で運用する。

## 未確認事項

- Antigravity CLI（`agy`）側の正確なresume/continueフラグは未確認。`agy --help`で確認すること。
  状態の保存先が`$HOME`配下であれば、上記の永続化は同様に効くはず。
- Dockerfile内の`antigravity.google/cli/install.sh`はネットワークアクセスが必要（サンドボックス
  環境のビルドでは未検証）。実際にWSLホスト上で`bash devbox/setup.sh`を実行して確認すること。
