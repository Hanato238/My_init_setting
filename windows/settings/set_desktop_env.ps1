Set-ExecutionPolicy Bypass -Scope Process -Force

# public desktop path
$desktopPathes = @("C:\Users\Public\Desktop", "C:\Users\lesen\Desktop", "C:\Users\Administrator\Desktop")

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
##$apps = @(
##)

# create shortcuts
##foreach ($app in $apps) {
##    $shortcut = $shell.CreateShortcut("$desktopPath\$($app.Name).lnk")
##    $shortcut.TargetPath = $app.Target
##    $shortcut.Save()
##}