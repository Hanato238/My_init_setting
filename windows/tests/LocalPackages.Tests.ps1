BeforeAll {
    $localPackagesDir = "$PSScriptRoot\..\installer\packages\local"
    $script:packageFolders = Get-ChildItem -Path $localPackagesDir -Directory
}

Describe "packages/local/<id>" {
    It "has at least one local package" {
        $script:packageFolders.Count | Should -BeGreaterThan 0
    }

    $testCases = $script:packageFolders | ForEach-Object { @{ Folder = $_ } }

    It "<Folder> has exactly one .nuspec whose id matches the folder name" -TestCases $testCases {
        param($Folder)
        $nuspecs = Get-ChildItem -Path $Folder.FullName -Filter '*.nuspec'
        $nuspecs.Count | Should -Be 1
        $nuspecs[0].BaseName | Should -Be $Folder.Name
    }

    It "<Folder> has chocolateyInstall.ps1 and chocolateyUninstall.ps1 under tools\" -TestCases $testCases {
        param($Folder)
        Test-Path (Join-Path $Folder.FullName 'tools\chocolateyInstall.ps1') | Should -BeTrue
        Test-Path (Join-Path $Folder.FullName 'tools\chocolateyUninstall.ps1') | Should -BeTrue
    }

    It "<Folder> does not bundle large binaries (installers must be downloaded or staged externally)" -TestCases $testCases {
        param($Folder)
        $maxBytes = 1MB
        $tooBig = Get-ChildItem -Path $Folder.FullName -Recurse -File |
            Where-Object { $_.Length -gt $maxBytes }
        if ($tooBig) { $tooBig | ForEach-Object { Write-Host "TOO BIG: $($_.FullName) ($([math]::Round($_.Length / 1MB, 1)) MB)" -ForegroundColor Red } }
        $tooBig | Should -BeNullOrEmpty
    }
}
