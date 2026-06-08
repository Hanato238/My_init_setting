param([switch]$DryRun)

Set-ExecutionPolicy Bypass -Scope Process -Force

# Check if office is already installed
$officePath = "C:\Program Files\Microsoft Office\root\Office16"
if (Test-Path $officePath) {
    Write-Host "Office is already installed at $officePath" -ForegroundColor Yellow
    return
}

if ($DryRun) {
    Write-Host "[DRY RUN] Would download and install Microsoft Office 2021 Enterprise" -ForegroundColor Yellow
    Write-Host "[DRY RUN] setup.exe /configure configuration-Office2021Enterprise.xml" -ForegroundColor Yellow
    return
}

# Google Drive File ID for setup.exe
$fileId = "18vddendGM5lN7Uul9_iNttma0GfiQDiv"
$setupExeUrl  = "https://drive.google.com/uc?export=download&id=$fileId"
$configXmlUrl = "https://raw.githubusercontent.com/hanato238/My_init_setting/main/windows/app_data/configuration-Office2021Enterprise.xml"

$targetDir = "C:\Windows\Temp\office_setup"
if (-not (Test-Path -Path $targetDir)) {
    New-Item -Path $targetDir -ItemType Directory -Force | Out-Null
}

$setupExePath  = Join-Path $targetDir "setup.exe"
$configXmlPath = Join-Path $targetDir "configuration-Office2021Enterprise.xml"

if (-not (Test-Path $setupExePath)) {
    Write-Host "Downloading setup.exe from Google Drive..." -ForegroundColor Cyan
    Invoke-WebRequest -Uri $setupExeUrl -OutFile $setupExePath
}

if (-not (Test-Path $configXmlPath)) {
    Write-Host "Downloading configuration XML from GitHub..." -ForegroundColor Cyan
    Invoke-WebRequest -Uri $configXmlUrl -OutFile $configXmlPath
}

Write-Host "Starting Office installation..." -ForegroundColor Cyan
Start-Process -FilePath $setupExePath -ArgumentList "/configure `"$configXmlPath`"" -Wait
