# Run PowerShell as Administrator before executing this script

# Set execution policy to allow script execution
Set-ExecutionPolicy Bypass -Scope Process -Force

# install Chocolatey and else
iex (iwr "http://raw.githubusercontent.com/hanato238/My_init_setting/main/windows/installer/chocolatey_installer.ps1")

# install apps
iex (iwr "http://raw.githubusercontent.com/hanato238/My_init_setting/main/windows/installer/apps.ps1")

# install office
iex (iwr "http://raw.githubusercontent.com/hanato238/My_init_setting/main/windows/installer/office_installer.ps1")

# set workspace and aliases
& "$PSScriptRoot\settings\set_workspace.ps1"
& "$PSScriptRoot\settings\set_aliases.ps1"

# setup MCP servers
& "$PSScriptRoot\installer\setup_security.ps1"    # 秘密情報をBitwardenから取得
& "$PSScriptRoot\settings\install_mcp_repos.ps1" # Extensionの自動インストール
& "$PSScriptRoot\settings\set_mcp_servers.ps1"   # その他のサーバーの登録