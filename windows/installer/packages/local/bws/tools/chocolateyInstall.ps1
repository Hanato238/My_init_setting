$ErrorActionPreference = 'Stop'

$packageName = 'bws'
$version     = '2.1.0'
$toolsDir    = Split-Path -Parent $MyInvocation.MyCommand.Definition

# Official prebuilt binaries from the sdk-sm releases. The zip contains a bare
# bws.exe; Chocolatey auto-shims it onto PATH. Checksums from
# https://github.com/bitwarden/sdk-sm/releases/download/bws-v2.1.0/bws-sha256-checksums-2.1.0.txt
$base       = "https://github.com/bitwarden/sdk-sm/releases/download/bws-v$version"
$urlX64      = "$base/bws-x86_64-pc-windows-msvc-$version.zip"
$checksumX64 = '8d6f2b51beb6f992b5b1de8b85a98bdf18de74096b724d17fa06219fc23f2bd5'
$urlArm64      = "$base/bws-aarch64-pc-windows-msvc-$version.zip"
$checksumArm64 = 'ba18adeb5d123481211c47c4e4d0ad6d81a6b0139150704785542fdee542e583'

if ($env:PROCESSOR_ARCHITECTURE -eq 'ARM64') {
    $url = $urlArm64; $checksum = $checksumArm64
} else {
    $url = $urlX64;   $checksum = $checksumX64
}

Install-ChocolateyZipPackage `
    -PackageName $packageName `
    -Url $url `
    -Checksum $checksum `
    -ChecksumType 'sha256' `
    -UnzipLocation $toolsDir
