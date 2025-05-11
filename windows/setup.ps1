# Run PowerShell as Administrator before executing this script

# Set execution policy to allow script execution
Set-ExecutionPolicy Bypass -Scope Process -Force

# install Chocolatey and else
iex (iwr "http://raw.githubusercontent.com/hanato238/My_init_setting/main/windows/installer/chocolatey_installer.ps1")

# install apps for clinic
iex (iwr "http://raw.githubusercontent.com/hanato238/My_init_setting/main/windows/installer/apps_clinic.ps1")

# install office
iex (iwr "http://raw.githubusercontent.com/hanato238/My_init_setting/main/windows/installer/office_installer.ps1")

# set workspace and aliases
iex (iwr "http://raw.githubusercontent.com/hanato238/My_init_setting/main/windows/settings/set_workspace.ps1")
iex (iwr "http://raw.githubusercontent.com/hanato238/My_init_setting/main/windows/settings/set_aliases.ps1")