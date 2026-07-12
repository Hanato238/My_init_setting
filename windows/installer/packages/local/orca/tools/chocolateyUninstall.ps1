$ErrorActionPreference = 'Stop'

$packageName = 'orca'

# Windowsのアンインストール情報からアンインストーラーを自動検出する
$uninstallKey = Get-UninstallRegistryKey -SoftwareName 'Orca*'

if ($uninstallKey.Count -eq 0) {
    Write-Warning "$packageName has already been uninstalled by other means."
    return
}

if ($uninstallKey.Count -gt 1) {
    $uninstallKey | ForEach-Object { Write-Verbose "Found key: $($_.DisplayName)" }
    Write-Warning "$packageName has multiple entries in registry. Please uninstall manually."
    return
}

$uninstallKey | ForEach-Object {
    $uninstallString = $_.UninstallString
    $silentArgs = '/S'

    if ($uninstallString -match '^"?(.+\.exe)"?\s*(.*)$') {
        $file = $matches[1]
        Uninstall-ChocolateyPackage `
            -PackageName $packageName `
            -FileType 'exe' `
            -SilentArgs $silentArgs `
            -File $file `
            -ValidExitCodes @(0)
    }
}
