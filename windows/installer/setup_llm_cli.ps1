Set-ExecutionPolicy Bypass -Scope Process -Force

# install claude-code-cli
choco install claude-code -y
# install gemini-cli
choco install gemini-cli -y

# install notebooklm-mcp-cli
uv tool install notebooklm-mcp-cli
nlm login
nlm setup add claude-code
nlm setup add gemini

# install openevidence-mcp
cd "$env:USERPROFILE\workspace\mcp-servers"
git clone https://github.com/bakhtiersizhaev/openevidence-mcp
cd ./openevidence-mcp
npx playwright install
npm install
npm run login
cd "$env:USERPROFILE\workspace"