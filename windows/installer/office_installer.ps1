Set-ExecutionPolicy Bypass -Scope Process -Force

# set github directory and files
$baseUrl = "https://raw.githubusercontent.com/hanato238/My_init_setting/main/windows/app_data/"
$fileNames = @("setup.exe", "configuration-Office2021Enterprise.xml")

# Set the target directory for the downloaded files
$targetDir = "C:\Widnows\Program Files\office"
if (-not (Test-Path -Path $targetDir)) {
    New-Item -Path $targetDir -ItemType Directory -Force
}
foreach ($file in $fileNames) {
    $url = "$baseUrl$file"
    $outPath = Join-Path $targetDir $file
    Invoke-WebRequest -Uri $url -OutFile $outPath
}

# Run the setup.exe with the configuration file
Set-Location $targetDir
Start-Process -FilePath ".\setup.exe" -ArgumentList "/configure .\configuration-Office2021Enterprise.xml" -Wait
