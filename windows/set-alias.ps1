# Aliasを設定

# 新しいAliasを登録する関数
function New-MyAlias {
    param(
        [string]$aliasName,
        [string]$command
    )
    
    # 登録するcommandが存在するかチェック
    $commandExists = Get-Command -Name $command -ErrorAction SilentlyContinue
    if (-not $commandExists){
        Write-Host "Error: '$command' is not found."
        return
    }
    # 既存のAliasを確認して、重複がないかチェック
    $aliasExists = Get-Alias -Name $aliasName -ErrorAction SilentlyContinue
    if ($aliasExists){
        Write-Host "Error: '$aliasName' already exists."
        return
    }

    # 新しいAliasを登録
    Set-Alias -Name $aliasName -Value $command
    Write-Host "New alias '$aliasName' is registered."
    
}

# 新しいAliasを登録
New-MyAlias -aliasName "admin" -command "Start-Process powershell -Verb runAs"
New-MyAlias -aliasName "chrome" -command "C:\Program Files\Google\Chrome\Application\chrome.exe"
New-MyAlias -aliasName "line" -command "C:\Users\lesen\AppData\Local\LINE\bin\LineLauncher.exe"
New-MyAlias -aliasName "vscode" -command "C:\Program Files\Microsoft VS Code\Code.exe"
New-MyAlias -aliasName "expressvpn" -command "C:\Program Files (x86)\ExpressVPN\expressvpn-ui\ExpressVPN.exe"
New-MyAlias -aliasName "kindle" -command "C:\Program Files (x86)\Amazon\Kindle\Kindle.exe"
