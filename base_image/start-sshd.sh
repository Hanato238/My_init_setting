#!/bin/sh
# コンテナの PID 1（base の CMD）。sshd を node ユーザーで起動する（設定は /etc/ssh/sshd_devcontainer.conf）。
set -eu

hostkey=/tmp/ssh_host_ed25519_key

# ホスト鍵はコンテナの起動ごとに作る（クライアントは照合しない）。
if [ ! -f "$hostkey" ]; then
    ssh-keygen -q -t ed25519 -N '' -f "$hostkey"
fi

# SSH セッションはコンテナの環境変数を引き継がないので、起動時の環境変数を書き出す。
# シェルやセッションごとに決まるものは除く。値に改行を含む変数は 2 行目以降が
# NAME=value の形にならないので、その行は書かない。
install -d -m 700 /home/node/.ssh
umask 077
env | grep -E '^[A-Za-z_][A-Za-z0-9_]*=' \
    | grep -Ev '^(HOSTNAME|HOME|PWD|OLDPWD|SHLVL|_|TERM)=' \
    > /home/node/.ssh/environment || true

exec /usr/sbin/sshd -D -e -f /etc/ssh/sshd_devcontainer.conf
