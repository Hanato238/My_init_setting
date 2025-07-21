Set-ExecutionPolicy Bypass -Scope Process -Force


## clear desktop shortcuts
# public desktop path
$desktopPathes = @("C:\Users\Public\Desktop", "$HOME\Desktop")
# remove existing shortcuts
foreach ($desktopPath in $desktopPathes) {
    if (Test-Path -Path $desktopPath) {
        Get-ChildItem -Path $desktopPath -Filter "*.lnk" | Remove-Item -Force
        Write-Host "Removing existing shortcuts from $desktopPath" -ForegroundColor Green
    } else {
        Write-Host "$desktopPath does not exist." -ForegroundColor Red
        continue
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
    Get-ChildItem -Path $taskbarPath -Filter "*.lnk" | Remove-Item -Force
    Write-Host "Removing existing shortcuts from $taskbarPath" -ForegroundColor Green
} else {
    Write-Host "$taskbarPath does not exist." -ForegroundColor Red
    continue
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