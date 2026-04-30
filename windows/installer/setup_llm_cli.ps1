Set-ExecutionPolicy Bypass -Scope Process -Force

# install claude-code-cli
npm install -g @anthropic-ai/claude-code
npm install -g @google/gemini-cli -y
refreshenv

# install 

# install gemini-cli

gemini mcp add filesystem npx @modelcontextprotocol/server-filesystem %USERPROFILE% --scope user 
gemini mcp add serena uvx --from git+https://github.com/oraios/serena serena start-mcp-server --scope user
gemini mcp add memory npx -y @modelcontextprotocol/server-memory --scope user
gemini mcp add context7 npx -y @upstash/context7-mcp --scope user
gemini mcp add markitdown uvx markitdown-mcp --scope user
gemini mcp add drawio npx -y @drawio/mcp --scope user
gemini mcp add youtube npx -y @anaisbetts/mcp-youtube --scope user
gemini mcp add perplexity npx -y @perplexity-ai/mcp-server -e PERPLEXITY_API_KEY=--scope user

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