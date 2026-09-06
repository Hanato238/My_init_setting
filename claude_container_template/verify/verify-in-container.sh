#!/usr/bin/env bash
# コンテナ内で bws / load-secrets / ~/.secrets の状態を点検する。
# 単体でも実行可:  bash /workspace/verify/verify-in-container.sh [secrets.list のパス]
set -uo pipefail

LIST_FILE="${1:-/workspace/.devcontainer/secrets.list}"
SECRETS_FILE="$HOME/.secrets"

mask() {
    local v="$1" n=${#1}
    if [ "$n" -le 6 ]; then printf '******'
    else printf '%s…%s (len=%d)' "${v:0:3}" "${v: -3}" "$n"
    fi
}

echo "=== 環境 ==="
printf '%-18s %s\n' "user"            "$(id -un)"
printf '%-18s %s\n' "bws"             "$(command -v bws || echo 'NOT FOUND')  $(bws --version 2>/dev/null | head -1)"
if [ -n "${BWS_ACCESS_TOKEN:-}" ]; then
    printf '%-18s %s\n' "BWS_ACCESS_TOKEN" "set ($(mask "$BWS_ACCESS_TOKEN"))"
else
    printf '%-18s %s\n' "BWS_ACCESS_TOKEN" "NOT set"
fi
if [ -r "$HOME/.config/bws/access-token" ]; then
    printf '%-18s %s\n' "token file" "$HOME/.config/bws/access-token (present)"
else
    printf '%-18s %s\n' "token file" "absent"
fi

echo
echo "=== bws 認証 (project list) ==="
if [ -n "${BWS_ACCESS_TOKEN:-}" ] && bws project list -o table 2>/dev/null; then
    :
else
    echo "  失敗 — トークン未設定か認証エラー"
fi

echo
echo "=== ~/.secrets ==="
if [ -f "$SECRETS_FILE" ]; then
    printf '%-18s %s\n' "path"  "$SECRETS_FILE"
    printf '%-18s %s\n' "perms" "$(stat -c '%a %U:%G' "$SECRETS_FILE")"
    printf '%-18s %s\n' "export 行数" "$(grep -c '^export ' "$SECRETS_FILE" 2>/dev/null || echo 0)"
else
    echo "  まだ存在しません (load-secrets.sh 未実行、または全て skip)"
fi

echo
echo "=== secrets.list の各名前の解決状況 ==="
if [ ! -r "$LIST_FILE" ]; then
    echo "  リストが読めません: $LIST_FILE"
    exit 1
fi
mapfile -t NAMES < <(sed -E 's/#.*//; s/[[:space:]]//g' "$LIST_FILE" | grep -E '^[A-Za-z_][A-Za-z0-9_]*$' || true)
if [ "${#NAMES[@]}" -eq 0 ]; then
    echo "  有効な名前なし (すべてコメントアウト)"
    exit 0
fi

printf '  %-26s %-11s %s\n' "NAME" "SOURCE" "VALUE"
printf '  %-26s %-11s %s\n' "----" "------" "-----"
n_file=0; n_env=0; n_missing=0
for name in "${NAMES[@]}"; do
    in_file=no
    grep -qE "^export ${name}=" "$SECRETS_FILE" 2>/dev/null && in_file=yes
    val="$(printenv "$name" 2>/dev/null || true)"
    if [ "$in_file" = yes ]; then
        src="bws→file"; n_file=$((n_file+1))
    elif [ -n "$val" ]; then
        src="host/env"; n_env=$((n_env+1))
    else
        src="MISSING"; n_missing=$((n_missing+1))
    fi
    printf '  %-26s %-11s %s\n' "$name" "$src" "$([ -n "$val" ] && mask "$val" || echo '-')"
done

echo
echo "  bws→file: $n_file   host/env: $n_env   MISSING: $n_missing   (total ${#NAMES[@]})"
[ "$n_missing" -eq 0 ]
