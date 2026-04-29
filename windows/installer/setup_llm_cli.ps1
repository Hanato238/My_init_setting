Set-ExecutionPolicy Bypass -Scope Process -Force

# install claude-code-cli
npm install -g @anthropic-ai/claude-code
npm install @google/gemini-cli -y
refreshenv

# install 
claude mcp add github --scope user -- npx -y @modelcontextprotocol/server-github
claude mcp add context7 --scope user -- npx -y @upstash/context7-mcp
claude mcp add playwright --scope project -- npx -y @playwright/mcp@latest
claude mcp add memory --scope user -- npx -y @modelcontextprotocol/server-memory
claude mcp add markitdown -s project -- uvx markitdown-mcp
claude mcp add youtube -s project -- npx @anaisbetts/mcp-youtube

# install gemini-cli
gemini extensions install https://github.com/googleworkspace/cli
gemini extensions install https://github.com/google/clasp
gemini extensions install https://github.com/gemini-cli-extensions/security
gemini extensions install https://github.com/gemini-cli-extensions/workspace
gemini extensions install https://github.com/gemini-cli-extensions/web-accessibility
gemini extensions install https://github.com/gemini-cli-extensions/observability
gemini extensions install https://github.com/gemini-cli-extensions/cloud-resource-manager
gemini extensions install https://github.com/github/github-mcp-server
gemini extensions install https://github.com/upstash/context7
gemini extensions install 

# install notebooklm-mcp-cli
uv tool install notebooklm-mcp-cli
nlm auth login
nlm setup add claude-code
nlm setup add gemini

# install openevidence-mcp
cd "$env:USERPROFILE\workspace\mcp-servers"
git clone https://github.com/bakhtiersizhaev/openevidence-mcp
cd ./openevidence-mcp
npm playwright install
npm install
npm run login
cd "$env:USERPROFILE\workspace"