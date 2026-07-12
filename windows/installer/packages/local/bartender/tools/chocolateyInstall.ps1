$ErrorActionPreference = 'Stop'

$packageName = 'bartender'
$toolsDir = Split-Path -parent $MyInvocation.MyCommand.Definition
if ([string]::IsNullOrEmpty($toolsDir)) {
    $toolsDir = Join-Path $env:ChocolateyPackageFolder 'tools'
}

# --- Parse --params "/Key:Value /Switch" -------------------------------------------------
# (named $paramMatches, not $matches, since $matches is PowerShell's automatic -match variable)
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
# 0. Locate the (large, licensed) Seagull installers
# =====================================================================================
# This package is a thin wrapper only - it does not bundle BarTender's installers inside
# the .nupkg. They must be downloaded/copied onto the target machine ahead of time. Looked
# up in order:
#   1. Alongside this script (tools\<Category>\<FileName>), in case someone builds a fully
#      self-contained nupkg for offline/internal-feed distribution.
#   2. $env:CHOCO_LOCAL_ASSETS\Bartender\<Category>\<FileName>
#   3. C:\ChocoLocalAssets\Bartender\<Category>\<FileName> (default when the env var above
#      is not set)
function Resolve-BartenderAsset($category, $fileName) {
    $candidates = @(
        (Join-Path $toolsDir $fileName),
        (Join-Path $toolsDir (Join-Path $category $fileName))
    )
    $assetsRoot = if ($env:CHOCO_LOCAL_ASSETS) { $env:CHOCO_LOCAL_ASSETS } else { 'C:\ChocoLocalAssets' }
    $candidates += Join-Path $assetsRoot (Join-Path 'Bartender' (Join-Path $category $fileName))

    $found = $candidates | Where-Object { Test-Path $_ } | Select-Object -First 1
    if (-not $found) {
        throw "Required file '$fileName' not found. Place it at '$(Join-Path $assetsRoot (Join-Path 'Bartender' (Join-Path $category $fileName)))' (or set `$env:CHOCO_LOCAL_ASSETS` to point at a different asset root) before installing."
    }
    return $found
}

# =====================================================================================
# 1. BarTender (label design software)
# =====================================================================================
if (-not (Get-Param 'SkipBarTender')) {
    $bartenderExe = Resolve-BartenderAsset 'BarTender' 'BarTender_Label Design Software.exe'

    if (Get-Param 'Modern') {
        # Seagull's officially documented silent install syntax, but only for BarTender 2019+:
        # setup.exe FEATURE=[features] PKC=[key] BLS=<host:port> INSTALLDIR=[path] INSTALLSQL=[true/false]
        # Confirmed NOT to work against the exe bundled in this package (exit code 1203 - the
        # installer rejects the FEATURE= public property). Kept as an opt-in for if/when the
        # bundled installer is swapped for a newer build. No product key is embedded in this
        # package - pass one with --params if you have it.
        $silentArgsParts = @("FEATURE=" + (Get-Param 'FEATURE' 'BarTender'))
        $pkc = Get-Param 'PKC'
        if ($pkc) { $silentArgsParts += "PKC=$pkc" }
        $bls = Get-Param 'BLS'
        if ($bls) { $silentArgsParts += "BLS=$bls" }
        $installDir = Get-Param 'INSTALLDIR'
        if ($installDir) { $silentArgsParts += "INSTALLDIR=`"$installDir`"" }
        # Default to false so `choco install` doesn't silently pull in SQL Server Express;
        # Seagull's own default is "true" if this is omitted.
        $silentArgsParts += "INSTALLSQL=" + (Get-Param 'INSTALLSQL' 'false')
        $ppw = Get-Param 'PRINTPORTAL_ACCOUNT_PASSWORD'
        if ($ppw) { $silentArgsParts += "PRINTPORTAL_ACCOUNT_PASSWORD=$ppw" }
        $silentArgs = $silentArgsParts -join ' '

        Install-ChocolateyInstallPackage -PackageName $packageName -FileType 'exe' `
            -File $bartenderExe -SilentArgs $silentArgs -ValidExitCodes @(0, 3010)
    } else {
        # Default: classic InstallShield "/s /v\"/qn ...\"" silent form. Confirmed working
        # against the exe bundled in this package (its InstallShield engine - 11.0.3146,
        # 2018-08 build - predates Seagull's 2019+ "FEATURE=" syntax above). Pass /Modern to
        # try the newer syntax instead (e.g. after updating the bundled installer).
        $addlocal = Get-Param 'ADDLOCAL' 'BarTender'
        $installDir = Get-Param 'INSTALLDIR'
        $vArgs = "/qn ADDLOCAL=$addlocal REBOOT=ReallySuppress"
        if ($installDir) { $vArgs += " INSTALLDIR=`"$installDir`"" }
        $silentArgs = "/s /v`"$vArgs`""
        Install-ChocolateyInstallPackage -PackageName $packageName -FileType 'exe' `
            -File $bartenderExe -SilentArgs $silentArgs -ValidExitCodes @(0, 3010)
    }
}

# =====================================================================================
# 2. Drivers by Seagull (printer driver files + optional driver install via DriverWizard)
# =====================================================================================
if (-not (Get-Param 'SkipDriver')) {
    $driverExtractDir = Get-Param 'DriverExtractDir'

    if ($driverExtractDir) {
        Write-Host "Using pre-extracted driver files at: $driverExtractDir"
    } else {
        $driverExe = Resolve-BartenderAsset 'Driver' 'BeeprtPrinter_2024.2.exe'

        # NOTE: Seagull's own "Installing Drivers by Seagull" technical document walks through
        # this step as an interactive wizard (license agreement -> destination folder -> Finish)
        # and, unlike the BarTender installer and DriverWizard.exe below, documents no silent or
        # unattended command-line switch for it. We deliberately do not guess at an undocumented
        # destination-folder switch here (a wrong flag could pop an error dialog and hang an
        # unattended install worse than no flag at all) - it is launched plain, and the wizard's
        # own default extraction folder is located afterwards. If you need a fully unattended
        # run, extract once interactively, then pass /DriverExtractDir:"C:\path\to\extracted"
        # on subsequent installs to skip this step entirely.
        Write-Warning "Launching the Seagull driver extractor - no documented silent switch exists for this step; a UI may appear and require you to click through it."
        Start-Process -FilePath $driverExe -Wait

        # Documented default unpack locations (see "Installing Drivers by Seagull" technical
        # document): Desktop\Seagull\<version> for 2017.1+, C:\Seagull for 7.4.3 and earlier.
        $candidates = @(
            (Join-Path ([Environment]::GetFolderPath('Desktop')) 'Seagull'),
            (Join-Path ([Environment]::GetFolderPath('CommonDesktopDirectory')) 'Seagull'),
            'C:\Seagull'
        )
        $driverExtractDir = $candidates | Where-Object { Test-Path $_ } | Select-Object -First 1
        if (-not $driverExtractDir) {
            Write-Warning "Could not locate the extracted driver files in any of the default locations (looked in: $($candidates -join ', ')). Pass /DriverExtractDir:`"C:\actual\path`" with --params to point at them."
            $driverExtractDir = $toolsDir
        }
    }

    $driverWizard = Get-ChildItem -Path $driverExtractDir -Filter 'DriverWizard.exe' -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $driverWizard) {
        Write-Warning "DriverWizard.exe was not found under $driverExtractDir - skipping printer driver installation. Driver system files (if extracted) remain available there for manual installation."
    } else {
        # Documented DriverWizard.exe command-line install syntax (v7.2+):
        #   DriverWizard.exe install /name:"..." /model:"..." /port:"..." [/default] [/share:"..."]
        #   DriverWizard.exe install /autodetect
        # These are environment/printer-specific, so nothing runs unless you supply them.
        if (Get-Param 'Autodetect') {
            & $driverWizard.FullName install /autodetect
        } elseif ((Get-Param 'PrinterName') -and (Get-Param 'PrinterModel')) {
            $dwArgs = @('install', "/name:`"$(Get-Param 'PrinterName')`"", "/model:`"$(Get-Param 'PrinterModel')`"")
            $port = Get-Param 'PrinterPort'
            if ($port) { $dwArgs += "/port:`"$port`"" }
            if (Get-Param 'PrinterDefault') { $dwArgs += '/default' }
            $share = Get-Param 'PrinterShare'
            if ($share) { $dwArgs += "/share:`"$share`"" }
            Start-Process -FilePath $driverWizard.FullName -ArgumentList $dwArgs -Wait -NoNewWindow
        } else {
            Write-Host "No /PrinterName+/PrinterModel or /Autodetect parameter supplied - driver files were extracted but no printer driver was installed. Run DriverWizard.exe manually, or re-run with --params, e.g.:"
            Write-Host "  choco install bartender --params `"/PrinterName:'Label Printer' /PrinterModel:'Zebra ZT411' /PrinterPort:'LPT1' /default`""
        }
    }
}

# =====================================================================================
# 3. Instruction manual (reference copy alongside the BarTender installation)
# =====================================================================================
if (-not (Get-Param 'SkipManual')) {
    $manualSrc = Resolve-BartenderAsset 'Manual' '取扱説明書_Ver202505.pdf'
    $bartenderInstallDir = Get-Param 'INSTALLDIR' 'C:\Program Files\Seagull\BarTender'
    if (Test-Path $bartenderInstallDir) {
        Copy-Item -Path $manualSrc -Destination $bartenderInstallDir -Force -ErrorAction SilentlyContinue
    }
}
