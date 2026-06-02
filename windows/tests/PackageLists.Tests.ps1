BeforeAll {
    $packagesDir = "$PSScriptRoot\..\installer\packages"
}

Describe "winget-packages.ps1" {
    BeforeAll {
        . "$packagesDir\winget-packages.ps1"
    }

    It "defines wingetPackages variable" {
        $wingetPackages | Should -Not -BeNullOrEmpty
    }

    It "has at least one package" {
        $wingetPackages.Count | Should -BeGreaterThan 0
    }

    It "has no duplicate entries" {
        $dupes = $wingetPackages | Group-Object | Where-Object { $_.Count -gt 1 }
        if ($dupes) { $dupes | ForEach-Object { Write-Host "DUPE: $($_.Name)" -ForegroundColor Red } }
        $dupes | Should -BeNullOrEmpty
    }

    It "has no blank entries" {
        $wingetPackages | Where-Object { [string]::IsNullOrWhiteSpace($_) } | Should -BeNullOrEmpty
    }

    It "includes Chocolatey.Chocolatey" {
        $wingetPackages | Should -Contain "Chocolatey.Chocolatey"
    }
}

Describe "choco-packages.ps1" {
    BeforeAll {
        . "$packagesDir\choco-packages.ps1"
    }

    It "defines chocoPackages variable" {
        $chocoPackages | Should -Not -BeNullOrEmpty
    }

    It "has at least one package" {
        $chocoPackages.Count | Should -BeGreaterThan 0
    }

    It "has no duplicate entries" {
        $dupes = $chocoPackages | Group-Object | Where-Object { $_.Count -gt 1 }
        if ($dupes) { $dupes | ForEach-Object { Write-Host "DUPE: $($_.Name)" -ForegroundColor Red } }
        $dupes | Should -BeNullOrEmpty
    }

    It "has no blank entries" {
        $chocoPackages | Where-Object { [string]::IsNullOrWhiteSpace($_) } | Should -BeNullOrEmpty
    }
}

Describe "npm-packages.ps1" {
    BeforeAll {
        . "$packagesDir\npm-packages.ps1"
    }

    It "defines npmPackages variable" {
        $npmPackages | Should -Not -BeNullOrEmpty
    }

    It "has no duplicate entries" {
        $dupes = $npmPackages | Group-Object | Where-Object { $_.Count -gt 1 }
        if ($dupes) { $dupes | ForEach-Object { Write-Host "DUPE: $($_.Name)" -ForegroundColor Red } }
        $dupes | Should -BeNullOrEmpty
    }

    It "includes claude-code" {
        $npmPackages | Should -Contain "@anthropic-ai/claude-code"
    }

    It "includes gemini-cli" {
        $npmPackages | Should -Contain "@google/gemini-cli"
    }
}

Describe "Cross-list duplicate check" {
    BeforeAll {
        . "$packagesDir\winget-packages.ps1"
        . "$packagesDir\choco-packages.ps1"
    }

    It "winget and choco lists have no identical entries (case-insensitive)" {
        $wingetLower = $wingetPackages | ForEach-Object { $_.ToLower() }
        $chocoLower  = $chocoPackages  | ForEach-Object { $_.ToLower() }
        $overlap = $wingetLower | Where-Object { $chocoLower -contains $_ }
        $overlap | Should -BeNullOrEmpty
    }
}
