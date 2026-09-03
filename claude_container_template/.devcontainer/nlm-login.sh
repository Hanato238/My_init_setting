#!/usr/bin/env bash
# コンテナに GUI ブラウザが無いため、ホスト(Windows)側の Chrome を
# CDP 経由で借用して `nlm login` を実行するラッパー。
#
# 事前準備: ホスト側 PowerShell で1度だけ実行しておく
#   .devcontainer/host-chrome-debug.ps1
#
# 使い方 (コンテナ内):
#   .devcontainer/nlm-login.sh            # 通常ログイン
#   .devcontainer/nlm-login.sh --force    # 別アカウントで上書き
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROXY_PORT="${NLM_CDP_LISTEN_PORT:-9222}"

node "$SCRIPT_DIR/cdp-proxy.js" &
PROXY_PID=$!
trap 'kill "$PROXY_PID" 2>/dev/null || true' EXIT

echo "[nlm-login] ホスト側 Chrome (CDP) への接続を待機中..."
ready=false
for _ in $(seq 1 20); do
  if curl -fsS -o /dev/null "http://127.0.0.1:${PROXY_PORT}/json/version" 2>/dev/null; then
    ready=true
    break
  fi
  sleep 0.5
done

if [ "$ready" != "true" ]; then
  echo "[nlm-login] エラー: ホスト側 Chrome (port ${PROXY_PORT}) に接続できません。" >&2
  echo "  先に Windows 側で以下を実行してください:" >&2
  echo "    .devcontainer/host-chrome-debug.ps1" >&2
  exit 1
fi

nlm login --cdp-url "http://127.0.0.1:${PROXY_PORT}" "$@"
