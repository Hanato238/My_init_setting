#!/usr/bin/env bash
# Bitwarden Secrets Manager CLI (bws) のアクセストークンをコンテナ内に保存する。
#
# bws はブラウザ認証を伴わず、マシンアカウントのアクセストークン文字列だけで動く。
# そのトークンを ~/.config/bws/access-token (chmod 600) に保存し、以後ログインシェルは
# /etc/profile.d/bws.sh 経由で BWS_ACCESS_TOKEN を自動 export する。
#
# 使い方 (コンテナ内):
#   .devcontainer/bws-login.sh <access-token>          # 引数で渡す
#   BWS_ACCESS_TOKEN=xxx .devcontainer/bws-login.sh    # 環境変数で渡す
#   .devcontainer/bws-login.sh                         # 対話入力 (エコーなし)
#
# ホスト側からまとめて実行したい場合は .devcontainer/bws-login.ps1 を使う。
set -euo pipefail

TOKEN="${1:-${BWS_ACCESS_TOKEN:-}}"
if [ -z "$TOKEN" ]; then
  read -rsp "bws access token: " TOKEN
  echo
fi
if [ -z "$TOKEN" ]; then
  echo "[bws-login] エラー: アクセストークンが空です。" >&2
  exit 1
fi

DEST_DIR="${HOME}/.config/bws"
DEST_FILE="${DEST_DIR}/access-token"

mkdir -p "$DEST_DIR"
( umask 077; printf '%s' "$TOKEN" > "$DEST_FILE" )
chmod 600 "$DEST_FILE"
echo "[bws-login] トークンを $DEST_FILE に保存しました。"

if BWS_ACCESS_TOKEN="$TOKEN" bws project list -o none >/dev/null 2>&1; then
  echo "[bws-login] 認証 OK (bws project list 成功)。"
  echo "[bws-login] 新しいシェルを開くと BWS_ACCESS_TOKEN が自動で設定されます。"
else
  echo "[bws-login] 警告: bws project list に失敗しました。トークンを確認してください。" >&2
  exit 1
fi
