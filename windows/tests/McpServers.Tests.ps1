BeforeAll {
    $settingsDir = "$PSScriptRoot\..\settings"
    $scriptPath  = "$settingsDir\Set-McpServers.ps1"

    # Pass a nonexistent path so main body returns early, but functions get defined
    . $scriptPath -ServersPath "C:\__nonexistent__\mcp.json" 2>$null

    # Temp directory for test fixtures
    $script:tmpDir = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString())
    New-Item -ItemType Directory -Path $script:tmpDir | Out-Null

    # Build sample MCP config as JSON string (avoids hashtable quoted-key parsing issues)
    $script:sampleMcp = @'
{
  "mcpServers": {
    "git":    { "type": "stdio", "command": "uvx", "args": ["mcp-server-git"] },
    "fetch":  { "type": "stdio", "command": "uvx", "args": ["mcp-server-fetch"] },
    "memory": { "type": "stdio", "command": "npx", "args": ["@modelcontextprotocol/server-memory"] },
    "sequential-thinking": { "type": "stdio", "command": "npx", "args": ["@modelcontextprotocol/server-sequential-thinking"] },
    "github": { "type": "stdio", "command": "npx", "args": ["@modelcontextprotocol/server-github"] }
  }
}
'@

    $script:srcPath    = Join-Path $script:tmpDir "mcp.json"
    $script:claudePath = Join-Path $script:tmpDir "claude.json"
    $script:geminiDir  = Join-Path $script:tmpDir "gemini"
    $script:geminiPath = Join-Path $script:geminiDir "settings.json"

    $utf8NoBom = New-Object System.Text.UTF8Encoding $false
    [System.IO.File]::WriteAllText($script:srcPath, $script:sampleMcp, $utf8NoBom)
    New-Item -ItemType Directory -Path $script:geminiDir -Force | Out-Null
}

AfterAll {
    if ($script:tmpDir -and (Test-Path $script:tmpDir)) {
        Remove-Item -Path $script:tmpDir -Recurse -Force
    }
}

Describe "Ensure-JsonFile" {
    It "creates an empty JSON file if not present" {
        $newFile = Join-Path $script:tmpDir "new_file.json"
        Ensure-JsonFile $newFile
        Test-Path $newFile | Should -Be $true
        (Get-Content $newFile -Raw).Trim() | Should -Be "{}"
    }

    It "does not overwrite an existing file" {
        $existingFile = Join-Path $script:tmpDir "existing.json"
        Set-Content $existingFile '{"existing":true}'
        Ensure-JsonFile $existingFile
        (Get-Content $existingFile -Raw) | Should -Match '"existing"'
    }

    It "creates missing parent directories" {
        $nestedFile = Join-Path $script:tmpDir "sub\dir\nested.json"
        Ensure-JsonFile $nestedFile
        Test-Path $nestedFile | Should -Be $true
    }
}

Describe "Merge-GeminiMcpServers" {
    It "writes only the specified keys to settings.json" {
        $geminiKeys = @('git', 'fetch', 'memory', 'sequential-thinking')
        Merge-GeminiMcpServers $script:geminiPath $script:srcPath $geminiKeys

        $result = Get-Content $script:geminiPath -Raw | ConvertFrom-Json
        $keys = $result.mcpServers.PSObject.Properties.Name

        $keys | Should -Contain "git"
        $keys | Should -Contain "fetch"
        $keys | Should -Contain "memory"
        $keys | Should -Contain "sequential-thinking"
        $keys | Should -Contain "time"        # always injected
        $keys | Should -Not -Contain "github" # excluded by filter
    }

    It "always injects the time server" {
        $result = Get-Content $script:geminiPath -Raw | ConvertFrom-Json
        $result.mcpServers.time.command | Should -Be "uvx"
        $result.mcpServers.time.args    | Should -Contain "mcp-server-time"
    }
}

Describe "Merge-ClaudeMcpServers" -Skip:(-not (Get-Command jq -ErrorAction SilentlyContinue)) {
    It "merges all MCP servers into claude.json" {
        Merge-ClaudeMcpServers $script:claudePath $script:srcPath

        $result = Get-Content $script:claudePath -Raw | ConvertFrom-Json
        $keys = $result.mcpServers.PSObject.Properties.Name

        $keys | Should -Contain "git"
        $keys | Should -Contain "fetch"
        $keys | Should -Contain "github"
    }

    It "preserves non-mcpServers fields in existing claude.json" {
        $existingClaude = Join-Path $script:tmpDir "claude_existing.json"
        $utf8NoBom = New-Object System.Text.UTF8Encoding $false
        [System.IO.File]::WriteAllText($existingClaude, '{"theme":"dark","mcpServers":{}}', $utf8NoBom)

        Merge-ClaudeMcpServers $existingClaude $script:srcPath

        $result = Get-Content $existingClaude -Raw | ConvertFrom-Json
        $result.mcpServers.PSObject.Properties.Name | Should -Contain "git"
        $result.theme | Should -Be "dark"
    }
}
