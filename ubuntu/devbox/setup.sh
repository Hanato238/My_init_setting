#!/bin/bash
set -e

# Local Docker Engine devbox: builds an image containing tmux + Claude Code +
# Antigravity CLI (agy) + Google Chrome, then runs it as a long-lived
# container on this WSL host's Docker Engine with this repo bind-mounted and
# $HOME on a named volume. Run as your regular sudo-capable user (needs the
# `docker` group - see ubuntu/wsl-setup/install_apps.sh), not as root.
#
# GUI passthrough (WSLg): if this host has WSLg (Windows 11, or Windows 10
# 21H2+ with `wsl --update`), this script shares its X11/Wayland sockets into
# the container so GUI apps installed there (Chrome) can show a window on the
# Windows desktop. This is what lets a future nlm-login/gws-login run
# *inside* the container itself, instead of needing a Windows-host browser +
# CDP proxy / docker cp credential hand-off like
# claude_container_template/.devcontainer/ does - the container becomes its
# own self-contained "host" for these logins. See GUI_DOCKER_ARGS below and
# README.md.
#
# Persistence model (see the "セッションの引継ぎ" discussion this script came
# out of):
#   - tmux's live session (scrollback, running shells) does NOT survive a WSL
#     restart - that's just how processes work. This script doesn't try to
#     fix that; re-run it (or just `docker start` + attach) to get a fresh
#     tmux session after a restart.
#   - Claude Code's conversation history and Antigravity CLI's config live
#     under $HOME *inside the container*, which is a named Docker volume
#     ($HOME_VOLUME below), not the container's writable layer. That volume
#     outlives `docker stop`/`docker rm` of the container and WSL restarts -
#     only `docker volume rm` destroys it. So `claude --continue`/`--resume`
#     (and agy's own resume, once its exact flag is confirmed) keeps working
#     across restarts even if the container itself gets recreated.
#   - The project repo is bind-mounted read-write from the host, so edits are
#     identical files on both sides - nothing to sync.
#
# Safe to re-run: image build is a no-op if the Dockerfile hasn't changed,
# volume creation is a no-op if it already exists, and the container is
# started (not recreated) if it already exists.

if [ "$EUID" -eq 0 ]; then
    echo "Error: do not run this with sudo/root. Run as your regular user (needs the docker group)." >&2
    exit 1
fi

if ! command -v docker &>/dev/null; then
    echo "Error: docker not found. Run 'bash wsl-setup/setup.sh apps' first." >&2
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
PROJECT_NAME="$(basename "$PROJECT_ROOT")"

IMAGE_NAME="devbox"
CONTAINER_NAME="devbox"
HOME_VOLUME="devbox-home"
CONTAINER_WORKDIR="/workspace/$PROJECT_NAME"

echo "=== devbox setup (Docker + tmux + Claude Code + Antigravity CLI) ==="
echo "Project to mount: $PROJECT_ROOT -> $CONTAINER_WORKDIR"

# --- Image ---
echo "--- Building image '$IMAGE_NAME' (no-op if Dockerfile is unchanged) ---"
docker build -t "$IMAGE_NAME" "$SCRIPT_DIR"

# --- Persistent $HOME volume (survives container recreation/WSL restarts) ---
if docker volume inspect "$HOME_VOLUME" &>/dev/null; then
    echo "OK: volume '$HOME_VOLUME' already exists"
else
    echo "Creating persistent home volume '$HOME_VOLUME'..."
    docker volume create "$HOME_VOLUME" > /dev/null
fi

# --- WSLg GUI passthrough ---
# Only wired up if this host actually has WSLg (checked via $DISPLAY and the
# X11 socket dir) - skipped with a NOTE otherwise so this script still works
# on a plain headless WSL/Docker Engine host. This only takes effect at
# container *creation* (docker run, below) - an existing container predating
# this must be recreated (`docker rm -f "$CONTAINER_NAME"`, then re-run this
# script) to pick it up, since `docker start` can't add new mounts.
GUI_DOCKER_ARGS=()
if [ -n "${DISPLAY:-}" ] && [ -d /tmp/.X11-unix ]; then
    GUI_DOCKER_ARGS+=(-e "DISPLAY=$DISPLAY" -v /tmp/.X11-unix:/tmp/.X11-unix)
    if [ -d /mnt/wslg ]; then
        GUI_DOCKER_ARGS+=(-v /mnt/wslg:/mnt/wslg)
    fi
    if [ -n "${WAYLAND_DISPLAY:-}" ]; then
        GUI_DOCKER_ARGS+=(-e "WAYLAND_DISPLAY=$WAYLAND_DISPLAY")
    fi
    if [ -n "${XDG_RUNTIME_DIR:-}" ] && [ -d "$XDG_RUNTIME_DIR" ]; then
        GUI_DOCKER_ARGS+=(-e "XDG_RUNTIME_DIR=$XDG_RUNTIME_DIR")
        case "$XDG_RUNTIME_DIR" in
            /mnt/wslg/*) : ;; # already covered by the /mnt/wslg mount above
            *) GUI_DOCKER_ARGS+=(-v "$XDG_RUNTIME_DIR:$XDG_RUNTIME_DIR") ;;
        esac
    fi
    echo "OK: WSLg GUI passthrough enabled (DISPLAY=$DISPLAY)"
else
    echo "NOTE: \$DISPLAY not set / no /tmp/.X11-unix - skipping WSLg GUI passthrough."
    echo "      GUI apps (Chrome, for future nlm-login/gws-login) won't be able to show a window."
fi

# --- Container ---
if docker container inspect "$CONTAINER_NAME" &>/dev/null; then
    STATE="$(docker container inspect -f '{{.State.Status}}' "$CONTAINER_NAME")"
    if [ "$STATE" = "running" ]; then
        echo "OK: container '$CONTAINER_NAME' is already running"
    else
        echo "Starting existing container '$CONTAINER_NAME' (state was: $STATE)..."
        docker start "$CONTAINER_NAME" > /dev/null
    fi
else
    echo "Creating container '$CONTAINER_NAME'..."
    # No --rm: the container must survive `docker stop` (and WSL restarts, via
    # `docker start` afterwards) for the persistence story above to hold.
    docker run -d \
        --name "$CONTAINER_NAME" \
        -v "$HOME_VOLUME:/home/dev" \
        -v "$PROJECT_ROOT:$CONTAINER_WORKDIR" \
        -w "$CONTAINER_WORKDIR" \
        "${GUI_DOCKER_ARGS[@]}" \
        "$IMAGE_NAME" > /dev/null
fi

echo ""
echo "=== devbox ready ==="
echo ""
echo "Attach a tmux session inside the container (creates 'main' on first run,"
echo "re-attaches to it on later runs within the same container lifetime):"
echo "  docker exec -it $CONTAINER_NAME tmux new -A -s main"
echo ""
echo "Inside that tmux session:"
echo "  claude --continue     # resume last Claude Code conversation in this dir"
echo "  claude --resume       # pick a conversation to resume"
echo "  agy --help            # confirm agy's own resume/continue flag"
echo ""
if [ ${#GUI_DOCKER_ARGS[@]} -gt 0 ]; then
    echo "Test the WSLg GUI passthrough (a Chrome window should appear on your"
    echo "Windows desktop):"
    echo "  docker exec -it $CONTAINER_NAME google-chrome --no-sandbox https://www.google.com"
    echo "  (--no-sandbox is needed because Chrome's own sandbox needs container"
    echo "   privileges this setup doesn't grant - fine for a one-off login flow)"
    echo ""
fi
echo "After a WSL restart: re-run this script (idempotent) to get Docker Engine"
echo "and the container running again, then re-attach as above. The tmux"
echo "window itself will be new, but claude --continue restores the"
echo "conversation content from the persisted '$HOME_VOLUME' volume."
