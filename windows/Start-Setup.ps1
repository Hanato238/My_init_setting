# Run PowerShell as Administrator before executing this script

# Set execution policy to allow script execution
Set-ExecutionPolicy Bypass -Scope Process -Force

# install Chocolatey and else
iex (iwr "https://raw.githubusercontent.com/hanato238/My_init_setting/main/windows/installer/Install-Chocolatey.ps1")

# install apps
iex (iwr "https://raw.githubusercontent.com/hanato238/My_init_setting/main/windows/installer/Install-Apps.ps1")

# install office
iex (iwr "https://raw.githubusercontent.com/hanato238/My_init_setting/main/windows/installer/Install-Office.ps1")

# set workspace and aliases
& "$PSScriptRoot\settings\Set-Workspace.ps1"
& "$PSScriptRoot\settings\Set-Aliases.ps1"

# setup MCP servers
& "$PSScriptRoot\installer\Initialize-Security.ps1"    # 秘密情報をBitwardenから取得
& "$PSScriptRoot\settings\Install-McpRepos.ps1" # Extensionの自動インストール
& "$PSScriptRoot\settings\Set-McpServers.ps1"   # その他のサーバーの登録
