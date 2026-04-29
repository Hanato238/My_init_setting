# 1. Temporarily bypass execution policy for the current process
Set-ExecutionPolicy Bypass -Scope Process -Force

# 2. Check for administrative privileges and auto-elevate if needed
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "Administrative privileges required. Elevating..." -ForegroundColor Yellow
    # Request elevation while maintaining the bypass policy
    Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

Write-Host "Running with administrative privileges..." -ForegroundColor Green


## clear desktop shortcuts
# public desktop path
$desktopPathes = @("C:\Users\Public\Desktop", "$HOME\Desktop")
# remove existing shortcuts
foreach ($desktopPath in $desktopPathes) {
    if (Test-Path -Path $desktopPath) {
        Write-Host "Checking: $desktopPath" -ForegroundColor Cyan
        try {
            # Filter shortcuts (exclude Recycle Bin/Trash)
            Get-ChildItem -Path $desktopPath -File | Where-Object { ($_.Extension -match '^\.(lnk|url)$') -and ($_.Name -notmatch '(?i)Recycle Bin|Trash') } | Remove-Item -Force -ErrorAction Stop
            Write-Host "Removing existing shortcuts (except Recycle Bin) from $desktopPath" -ForegroundColor Green
        }
        catch {
            Write-Warning "Failed to clear some items in $desktopPath (Maybe in use or permission issue)."
        }
    }
    else {
        Write-Host "$desktopPath does not exist." -ForegroundColor Yellow
    }
}

# com object for creating shortcuts
##$shell = New-Object -ComObject WScript.Shell


# shortcut paths
##$desktopApps = @(
##)

# create shortcuts
##foreach ($app in $apps) {
##    $shortcut = $shell.CreateShortcut("$desktopPublicPath\$($app.Name).lnk")
##    $shortcut.TargetPath = $app.Target
##    $shortcut.Save()
##}



## clear taskbar shortcuts
$taskbarPath = "$HOME\AppData\Roaming\Microsoft\Internet Explorer\Quick Launch\User Pinned\TaskBar"

# remove existing shortcuts
if (Test-Path -Path $taskbarPath) {
    try {
        # Filter shortcuts (exclude Recycle Bin/Trash)
        Get-ChildItem -Path $taskbarPath -File | Where-Object { ($_.Extension -match '^\.(lnk|url)$') -and ($_.Name -notmatch '(?i)Recycle Bin|Trash') } | Remove-Item -Force -ErrorAction Stop
        Write-Host "Removing existing shortcuts (except Recycle Bin) from $taskbarPath" -ForegroundColor Green
    }
    catch {
        Write-Warning "Failed to clear taskbar shortcuts."
    }
}
else {
    Write-Host "$taskbarPath does not exist." -ForegroundColor Yellow
}

# shortcut paths
##$taskbarApps = @(
##)

# create shortcuts
##foreach ($app in $apps) {
##    $shortcut = $shell.CreateShortcut("$taskbarPath\$($app.Name).lnk")
##    $shortcut.TargetPath = $app.Target
##    $shortcut.Save()
##}