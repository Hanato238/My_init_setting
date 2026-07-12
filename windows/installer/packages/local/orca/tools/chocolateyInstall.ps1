$ErrorActionPreference = 'Stop'

$packageName = 'orca'
$installerType = 'exe'
$silentArgs = '/S'
$validExitCodes = @(0)

$url = 'https://github.com/stablyai/orca/releases/download/v1.4.123/orca-windows-setup.exe'
$checksum = 'dbb74a2bb6c294169edb98ab505b022c474460d32dfb7799fe875d56b77f7d6f78e08e4c6f0d491c1c27e5f175834670127a766070a7e5e1a6122854a1d1991c'
$checksumType = 'sha512'

$toolsDir = Split-Path -parent $MyInvocation.MyCommand.Definition
$fileLocation = Join-Path $toolsDir 'orca-windows-setup.exe'

Get-ChocolateyWebFile `
    -PackageName $packageName `
    -FileFullPath $fileLocation `
    -Url $url `
    -Checksum $checksum `
    -ChecksumType $checksumType

Install-ChocolateyInstallPackage `
    -PackageName $packageName `
    -FileType $installerType `
    -SilentArgs $silentArgs `
    -File $fileLocation `
    -ValidExitCodes $validExitCodes
