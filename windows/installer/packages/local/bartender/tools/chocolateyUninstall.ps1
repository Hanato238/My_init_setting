$ErrorActionPreference = 'Stop'

$packageName = 'bartender'
$toolsDir = Split-Path -parent $MyInvocation.MyCommand.Definition
if ([string]::IsNullOrEmpty($toolsDir)) {
    $toolsDir = Join-Path $env:ChocolateyPackageFolder 'tools'
}

$pp = @{}
if ($env:chocolateyPackageParameters) {
    $paramMatches = [regex]::Matches($env:chocolateyPackageParameters, '/([a-zA-Z_]+)(:("([^"]*)"|([^\s]*)))?')
    foreach ($m in $paramMatches) {
        $key = $m.Groups[1].Value
        $val = if ($m.Groups[4].Success) { $m.Groups[4].Value } elseif ($m.Groups[5].Success) { $m.Groups[5].Value } else { $true }
        $pp[$key] = $val
    }
}
function Get-Param($name, $default = $null) { if ($pp.ContainsKey($name)) { $pp[$name] } else { $default } }

# =====================================================================================
# 1. Remove the printer driver via the Seagull Driver Wizard (if it was extracted here)
# =====================================================================================
if (-not (Get-Param 'SkipDriver')) {
    $driverExtractDir = Join-Path $toolsDir 'SeagullDriverFiles'
    $driverWizard = Get-ChildItem -Path $driverExtractDir -Filter 'DriverWizard.exe' -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($driverWizard) {
        $driverName = Get-Param 'PrinterModel'
        if ($driverName) {
            & $driverWizard.FullName remove "/driver:`"$driverName`""
        } else {
            Write-Warning "No /PrinterModel supplied to chocolateyUninstall - leaving the installed printer driver in place. Remove it manually with the Seagull Driver Wizard, or re-run: choco uninstall bartender --params `"/PrinterModel:'Your Driver Name'`""
        }
    }
}

# =====================================================================================
# 2. Uninstall BarTender itself via its registry uninstall entry
# =====================================================================================
$uninstallKey = Get-UninstallRegistryKey -SoftwareName 'BarTender*'

if ($uninstallKey.Count -eq 0) {
    Write-Warning "$packageName (BarTender) has already been uninstalled by other means."
} elseif ($uninstallKey.Count -gt 1) {
    $uninstallKey | ForEach-Object { Write-Verbose "Found key: $($_.DisplayName)" }
    Write-Warning "$packageName has multiple entries in registry. Please uninstall manually."
} else {
    $uninstallKey | ForEach-Object {
        $uninstallString = $_.UninstallString

        if ($uninstallString -match '(?i)msiexec\S*\s+.*(\{[0-9A-F\-]+\})') {
            # InstallShield "Basic MSI" projects register an MsiExec.exe /X{GUID} uninstall string.
            $productCode = $matches[1]
            Start-ChocolateyProcessAsAdmin -Statements "/X$productCode /qn REBOOT=ReallySuppress" -ExeToRun 'msiexec.exe' -ValidExitCodes @(0, 3010)
        } elseif ($uninstallString -match '^"?(.+\.exe)"?\s*(.*)$') {
            $file = $matches[1]
            Uninstall-ChocolateyPackage -PackageName $packageName -FileType 'exe' `
                -SilentArgs '/s /v"/qn REBOOT=ReallySuppress"' -File $file -ValidExitCodes @(0, 3010)
        } else {
            Write-Warning "Could not parse uninstall string for BarTender: $uninstallString"
        }
    }
}
