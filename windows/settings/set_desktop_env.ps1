Set-ExecutionPolicy Bypass -Scope Process -Force

# public desktop path
$desktopPath = "C:\Users\Public\Desktop\Zoom Workplace.lnk"

# remove existing shortcuts
Get-ChildItem -Path $desktopPath -Filter *.lnk | Remove-Item -Force

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