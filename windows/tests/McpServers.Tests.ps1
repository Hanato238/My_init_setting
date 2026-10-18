BeforeAll {
    $settingsDir = "$PSScriptRoot\..\settings"
    $scriptPath  = "$settingsDir\Set-McpServers.ps1"

    # Pass a nonexistent -McpDir so the main body returns early (before touching the real
    # ~/.claude.json / ~/.gemini/settings.json), but the functions still get defined.
    # Point the target paths at a nonexistent location too, in case the guard ever moves.
    . $scriptPath -McpDir "C:\__nonexistent__\mcp.d" `
                  -ClaudePath "C:\__nonexistent__\claude.json" `
                  -GeminiPath "C:\__nonexistent__\settings.json" 2>$null

    # Temp directory for test fixtures
    $script:tmpDir = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString())
    New-Item -ItemType Directory -Path $script:tmpDir | Out-Null

    $script:utf8NoBom = New-Object System.Text.UTF8Encoding $false

    # shared/mcp.d layout: one file per group, each a flat { "<server>": { ... } } object
    $script:mcpDir = Join-Path $script:tmpDir "mcp.d"
    New-Item -ItemType Directory -Path $script:mcpDir | Out-Null
    [System.IO.File]::WriteAllText((Join-Path $script:mcpDir "a-core.json"), @'
{
  "git":   { "type": "stdio", "command": "uvx", "args": ["mcp-server-git"] },
  "fetch": { "type": "stdio", "command": "uvx", "args": ["mcp-server-fetch"] }
}
'@, $script:utf8NoBom)
    [System.IO.File]::WriteAllText((Join-Path $script:mcpDir "b-extra.json"), @'
{
  "fetch":  { "type": "stdio", "command": "npx", "args": ["fetch-override"] },
  "github": { "type": "stdio", "command": "npx", "args": ["@modelcontextprotocol/server-github"] }
}
'@, $script:utf8NoBom)
    [System.IO.File]::WriteAllText((Join-Path $script:mcpDir "ignored.txt"), 'not json', $script:utf8NoBom)
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

Describe "Merge-McpDir" {
    It "combines servers from every *.json file" {
        $merged = Merge-McpDir $script:mcpDir
        $keys = $merged.PSObject.Properties.Name
        $keys | Should -Contain "git"
        $keys | Should -Contain "fetch"
        $keys | Should -Contain "github"
        $keys.Count | Should -Be 3
    }

    It "lets a later file (by name) override an earlier one" {
        $merged = Merge-McpDir $script:mcpDir
        $merged.fetch.command | Should -Be "npx"
        $merged.fetch.args    | Should -Contain "fetch-override"
    }
}

Describe "Set-McpServers" {
    BeforeAll {
        $script:servers = Merge-McpDir $script:mcpDir
    }

    It "writes only the specified keys and skips keys missing from the source" {
        $target = Join-Path $script:tmpDir "only-keys.json"
        Set-McpServers $target $script:servers @('git', 'github', 'not-defined')

        $keys = (Get-Content $target -Raw | ConvertFrom-Json).mcpServers.PSObject.Properties.Name
        $keys | Should -Contain "git"
        $keys | Should -Contain "github"
        $keys | Should -Not -Contain "fetch"
        $keys | Should -Not -Contain "not-defined"
    }

    It "replaces existing mcpServers and preserves other fields" {
        $target = Join-Path $script:tmpDir "existing-claude.json"
        [System.IO.File]::WriteAllText($target, '{"theme":"dark","mcpServers":{"old":{"command":"x"}}}', $script:utf8NoBom)

        Set-McpServers $target $script:servers @('git')

        $result = Get-Content $target -Raw | ConvertFrom-Json
        $result.theme | Should -Be "dark"
        $result.mcpServers.PSObject.Properties.Name | Should -Be @('git')
    }
}
