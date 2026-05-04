Set-ExecutionPolicy Bypass -Scope Process -Force

# Google Drive File ID for setup.exe
$fileId = "18vddendGM5lN7Uul9_iNttma0GfiQDiv"
$setupExeUrl = "https://drive.google.com/uc?export=download&id=$fileId"
$configXmlUrl = "https://raw.githubusercontent.com/hanato238/My_init_setting/main/windows/app_data/configuration-Office2021Enterprise.xml"

# Set the target directory for the downloaded files
$targetDir = "C:\Windows\Temp\office_setup"
if (-not (Test-Path -Path $targetDir)) {
    New-Item -Path $targetDir -ItemType Directory -Force
}

$setupExePath = Join-Path $targetDir "setup.exe"
$configXmlPath = Join-Path $targetDir "configuration-Office2021Enterprise.xml"

# Download setup.exe from Google Drive if it doesn't exist
if (-not (Test-Path $setupExePath)) {
    Write-Host "Downloading setup.exe from Google Drive..." -ForegroundColor Cyan
    Invoke-WebRequest -Uri $setupExeUrl -OutFile $setupExePath
}

# Download configuration XML from GitHub if it doesn't exist
if (-not (Test-Path $configXmlPath)) {
    Write-Host "Downloading configuration XML from GitHub..." -ForegroundColor Cyan
    Invoke-WebRequest -Uri $configXmlUrl -OutFile $configXmlPath
}

# Check if office is already installed
$officePath = "C:\Program Files\Microsoft Office\root\Office16"
if (Test-Path $officePath) {
    Write-Host "Office is already installed at $officePath" -ForegroundColor Yellow
    return
}

# Run the setup.exe with the configuration file
Write-Host "Starting Office installation..." -ForegroundColor Cyan
Start-Process -FilePath $setupExePath -ArgumentList "/configure `"$configXmlPath`"" -Wait
