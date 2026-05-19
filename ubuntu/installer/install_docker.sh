#!/bin/bash
set -e

if [ "$EUID" -eq 0 ]; then
    echo "Error: Do not run this script with sudo. Run as your regular user:" >&2
    echo "  bash ./installer/install_docker.sh" >&2
    exit 1
fi

echo "=== Docker Engine セットアップ (WSL2 ネイティブ) ==="

# --- Step 1: systemd の確認と有効化 ---
WSL_CONF="/etc/wsl.conf"

if [ "$(ps -p 1 -o comm=)" != "systemd" ]; then
    # systemd が動いていない → wsl.conf に追記して再起動を促す
    if ! grep -q "systemd=true" "$WSL_CONF" 2>/dev/null; then
        echo "systemd を有効化します..."
        if grep -q "\[boot\]" "$WSL_CONF" 2>/dev/null; then
            sudo sed -i '/\[boot\]/a systemd=true' "$WSL_CONF"
        else
            printf '\n[boot]\nsystemd=true\n' | sudo tee -a "$WSL_CONF" > /dev/null
        fi
    fi
    echo ""
    echo "WSL の再起動が必要です。PowerShell で以下を実行してください:"
    echo "  wsl --shutdown"
    echo ""
    echo "その後このスクリプトを再実行してください。"
    exit 0
fi

echo "OK: systemd 動作確認済み"

# --- Step 2: Docker Engine のインストール ---
# dpkg で確認（Docker Desktop 経由の docker コマンドを誤検知しないため）
if dpkg -s docker-ce &>/dev/null 2>&1; then
    echo "OK: $(docker --version) はインストール済みです"
else
    echo "Docker Engine をインストールします..."

    sudo apt-get update -q
    sudo apt-get install -y ca-certificates curl

    sudo install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
        | sudo tee /etc/apt/keyrings/docker.asc > /dev/null
    sudo chmod a+r /etc/apt/keyrings/docker.asc

    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] \
https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
        | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

    sudo apt-get update -q
    sudo apt-get install -y \
        docker-ce docker-ce-cli containerd.io \
        docker-buildx-plugin docker-compose-plugin

    echo "OK: $(docker --version)"
fi

# --- Step 3: docker グループへの追加 ---
if ! groups "$USER" | grep -q '\bdocker\b'; then
    sudo usermod -aG docker "$USER"
    echo "docker グループに追加しました（反映は次回ログイン時）"
else
    echo "OK: docker グループ登録済み"
fi

# --- Step 4: Docker サービスの有効化・起動 ---
if systemctl cat docker.service &>/dev/null; then
    sudo systemctl enable docker --quiet
    if ! systemctl is-active --quiet docker; then
        sudo systemctl start docker
    fi
    echo "OK: Docker サービス起動済み"
else
    echo "Error: docker.service が見つかりません。Docker Engine のインストールに失敗した可能性があります。" >&2
    exit 1
fi

echo ""
echo "--- Summary ---"
echo "$(docker --version)"
echo "$(docker compose version)"
echo ""
echo "新しいターミナルを開くと sudo なしで docker コマンドが使えます。"
