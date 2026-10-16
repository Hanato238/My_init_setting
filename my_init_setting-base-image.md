# 引き継ぎ: 共通ベースイメージ（ghcr.io）— My_init_setting 向け

- 宛先: `Hanato238/My_init_setting`（**公開リポジトリ**）
- 状況: 2026-10-16 に起票済み。#A = https://github.com/Hanato238/My_init_setting/issues/4 、#B = https://github.com/Hanato238/My_init_setting/issues/5 （#4 の sub-issue）。
- 以下は起票した本文の控え。#B の本文中の「#A」は、実際の issue では「#4」に置き換えた。

---

## Issue #A

**Title:** 共通ベースイメージ `ghcr.io/hanato238/claude-base` を作成し、Actions で公開する

**Body:**

```markdown
## 目的
Claude Code 用 devcontainer の共通部分（OS・基本ツール・Claude Code）を 1 つのベースイメージにまとめ、ghcr.io で公開する。
claude_container_template をはじめ、下流の Dockerfile はこれを FROM して、それぞれに必要な差分だけを足す。

## 決定事項
- レジストリ: ghcr.io（public）。GITHUB_TOKEN だけで push でき、パッケージがこのリポジトリに紐づき、Docker Hub の pull 制限がないため。
- イメージ名: `ghcr.io/hanato238/claude-base`（小文字）
- 中身は共通部分だけにする:
  - `FROM node:22-slim`（ARG で版を固定）
  - apt: procps curl ca-certificates gnupg jq git unzip ncurses-term bubblewrap socat ripgrep
    （bubblewrap/socat/ripgrep は Claude Code の Bash sandbox の依存）
  - zellij（ARG ZELLIJ_VERSION、musl バイナリ）
  - Claude Code（ARG CLAUDE_CODE_VERSION で固定し、`npm install -g @anthropic-ai/claude-code@${CLAUDE_CODE_VERSION}` の後に install.cjs を実行）
  - `ENV LANG=C.UTF-8 LC_ALL=C.UTF-8 SHELL=/bin/bash DISABLE_AUTOUPDATER=1`
  - 最後は `WORKDIR /workspace` と `USER node`
- 入れないもの（下流の責務）: uv / agy / gws / bws / gcloud / notebooklm-mcp-cli / claude-env / 秘密情報の読み込み / MCP サーバー / git の safe.directory 設定
- 秘密情報は一切含めない。
- アーキテクチャ: linux/amd64 のみ（ARM が必要になったら TARGETARCH 対応を追加）
- コンテナ内での Claude Code の自動更新は無効にする。版を上げるのはイメージの更新だけ。

## 作業
- [ ] `base_image/Dockerfile` を作成する
- [ ] `.github/workflows/base-image.yml` を作成する
  - トリガー: push to main（paths: `base_image/**`、workflow ファイル）と workflow_dispatch
  - `permissions: contents: read, packages: write`
  - docker/login-action（ghcr.io、GITHUB_TOKEN）→ docker/metadata-action → docker/build-push-action（platforms: linux/amd64、cache: gha）
  - タグ: `latest`、`YYYYMMDD`、`sha-<short>`
  - ラベル: `org.opencontainers.image.source`
- [ ] `renovate.json` を作成する（ARG の版を regex manager で追う。node / zellij は GitHub releases、Claude Code は npm を参照）
- [ ] 初回 push のあと、パッケージの visibility を public に変える（ghcr の初期設定は private）

## 受け入れ条件
- 認証なしで `docker pull ghcr.io/hanato238/claude-base:latest` が通る
- `docker run --rm ghcr.io/hanato238/claude-base:latest sh -c 'whoami; claude --version; zellij --version; bwrap --version'` で node・固定した版・各ツールが確認できる
- Renovate がイメージの版の更新 PR を作る
```

---

## Issue #B（#A の sub-issue）

**Title:** claude_container_template を claude-base の FROM に移行する

**Body:**

```markdown
## 目的
claude_container_template/.devcontainer/Dockerfile の共通部分を削り、`ghcr.io/hanato238/claude-base` を FROM する形にする。#A の完了が前提。

## 作業
- [ ] `FROM ghcr.io/hanato238/claude-base:<YYYYMMDD>` にする（日付タグで固定し、Renovate が更新する）
- [ ] 共通部分（apt の基本パッケージ・zellij・Claude Code・LANG/SHELL）を削る
- [ ] 残すもの: uv / agy / gws / bws / profile.d の読み込み / gcloud / notebooklm-mcp-cli / claude-env
- [ ] apt などの追加は `USER root` で行い、最後に `USER node` に戻す
- [ ] 既存の設定（claude-env setup の HOME=/home/node、chown など）が base の構成と矛盾しないか確認する

## 受け入れ条件
- テンプレートの devcontainer がビルド・起動でき、claude / bws / gcloud / agy / zellij が動く
- ビルド時間が以前より短くなる（共通部分のキャッシュが効く）
```

---

## 非公開メモ（公開 issue には書かない）

- 俯瞰コンテナの切り替え（#A の完了後にホスト側で実施）:
  `/workspace/.devcontainer/Dockerfile` の 3〜17 行目（FROM・apt・zellij）と 29〜31 行目（Claude Code）を
  `FROM ghcr.io/hanato238/claude-base:<日付>` に置き換える。
  残すもの: github-mcp-server / todoist-mcp / `safe.directory '*'` / `GIT_OPTIONAL_LOCKS=0` / `/etc/claude-code` / `CLAUDE_CONFIG_DIR`。
  base が `USER node` で終わるため、追加部分は `USER root` で始め、最後に `USER node` に戻す。
- grill での決定の経緯: ghcr.io を選んだ（public 前提で、Actions との統合と pull 制限なしが決め手）。中身は共通部分のみ。版は ARG 固定 + Renovate。amd64 のみ。自動更新は無効。2 段階構成（base → template → 子）。
- 2026-10-16 時点で GITHUB_MCP_PAT が 401 を返す。更新とコンテナの再起動が必要。
