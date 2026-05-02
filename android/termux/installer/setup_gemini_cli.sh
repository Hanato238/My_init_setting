#!/data/data/com.termux/files/usr/bin/bash
set -e

# Storage permission (run once, opens dialog)
termux-setup-storage

pkg update -y && pkg upgrade -y

# Core packages
pkg install -y nodejs-lts python git vim zip uv

# install gemini-cli
npm install -g @google/gemini-cli
npm install -g @bitwarden/cli


# add context7
gemini extensions install https://github.com/upstash/context7
gemini extensions install https://github.com/wonderwhy-er/DesktopCommanderMCP
gemini extensions install https://github.com/amelianoir/github-mcp-server
gemini extensions install https://github.com/gemini-cli-extensions/workspace
gemini extensions install https://github.com/google/clasp
gemini extensions install https://github.com/gemini-cli-extensions/security
gemini extensions install https://github.com/gemini-cli-extensions/web-accessibility
gemini extensions install https://github.com/gemini-cli-extensions/cloud-resource-manager
gemini extensions install https://github.com/Hanato238/modelcontextprotocol/tree/14e78d8e4b89930d909a4e4213f1dadb071f7a5f
gemini extensions install https://github.com/Hanato238/drawio-mcp/tree/ec48ca59dec9f5b4eae7e6080abb89be85b51acd
gemini extensions install https://github.com/yuys13/gemini-cli-extension-gyaru/tree/d514e191f71c55323fa6ec542de4b4c64a177e5c
gemini extensions install https://github.com/GoogleCloudPlatform/gcp-hardening-toolkit/tree/d72b8f9b87718195d41f4aed511feffcf90c8fb0
gemini extensions install https://github.com/Hanato238/servers/tree/c6fa93ccf9e7998cc30351c666700761845c5f45/src/filesystem
gemini extensions install https://github.com/Hanato238/servers/tree/c6fa93ccf9e7998cc30351c666700761845c5f45/src/fetch
gemini extensions install https://github.com/Hanato238/servers/tree/c6fa93ccf9e7998cc30351c666700761845c5f45/src/git
gemini extensions install https://github.com/Hanato238/servers/tree/c6fa93ccf9e7998cc30351c666700761845c5f45/src/memory
gemini extensions install https://github.com/Hanato238/servers/tree/c6fa93ccf9e7998cc30351c666700761845c5f45/src/sequentialthinking