#!/bin/sh
# コンテナの PID 1。sshd を node ユーザーで起動する（設定は sshd_config）。
set -eu

hostkey_dir=/home/node/.ssh-hostkeys
pubkey=/etc/devcontainer/authorized_key.pub

# ホスト鍵は名前付きボリュームに置き、再ビルドしても known_hosts と食い違わないようにする。
if [ ! -f "$hostkey_dir/ssh_host_ed25519_key" ]; then
    ssh-keygen -q -t ed25519 -N '' -f "$hostkey_dir/ssh_host_ed25519_key"
fi

# ホストの公開鍵が無いと Docker は空ディレクトリをマウントする。
if [ ! -f "$pubkey" ]; then
    echo "start-sshd: $pubkey がありません。ホストで llm を実行して鍵を作成してから起動してください。" >&2
    exit 1
fi
install -d -m 700 /home/node/.ssh
install -m 600 "$pubkey" /home/node/.ssh/authorized_keys

# sshd_config の PermitUserEnvironment に列挙した名前だけを書き出す。
umask 077
: > /home/node/.ssh/environment
for name in ANTHROPIC_API_KEY GITHUB_MCP_PAT PROJECT_NAME CLAUDE_CONFIG_DIR DISABLE_AUTOUPDATER LANG LC_ALL SHELL PATH; do
    eval "value=\${$name:-}"
    if [ -n "$value" ]; then
        printf '%s=%s\n' "$name" "$value" >> /home/node/.ssh/environment
    fi
done

exec /usr/sbin/sshd -D -e -f /etc/ssh/sshd_devcontainer.conf
