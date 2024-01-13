# タスクバーにピン止めするショートカットのパス
$taskbarPath = [System.IO.Path]::Combine($env:APPDATA, 'Microsoft\Internet Explorer\Quick Launch\User Pinned\TaskBar')
$shortcutPath = [System.IO.Path]::Combine($taskbarPath, 'Gmail.lnk')

# タスクバーにピン止めするショートカットを作成
if (-not (Test-Path $shortcutPath)) {
    $chromeExePath = (Get-Command chrome).Source
    $shell = New-Object -ComObject WScript.Shell
    $shortcut = $shell.CreateShortcut($shortcutPath)
    $shortcut.TargetPath = $chromeExePath
    $shortcut.Arguments = "--new-window https://mail.google.com/"
    $shortcut.Save()
}

Write-Host "Gmailのショートカットが作成され、タスクバーにピン止めされました。"
