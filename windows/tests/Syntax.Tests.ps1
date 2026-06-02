# Discover files at script load time (before BeforeAll) so TestCases can use them
$script:ps1Files = Get-ChildItem -Path "$PSScriptRoot\.." -Recurse -Filter "*.ps1" |
    Where-Object { $_.FullName -notlike "*\tests\*" }

Describe "PowerShell syntax check" {
    It "all .ps1 files parse without errors" {
        $allErrors = @()

        foreach ($file in $script:ps1Files) {
            $parseErrors = @()
            $null = [System.Management.Automation.Language.Parser]::ParseFile(
                $file.FullName, [ref]$null, [ref]$parseErrors
            )
            foreach ($err in $parseErrors) {
                $allErrors += "$($file.Name) [line $($err.Extent.StartLineNumber)]: $($err.Message)"
            }
        }

        if ($allErrors) { $allErrors | ForEach-Object { Write-Host "  $_" -ForegroundColor Red } }
        $allErrors | Should -BeNullOrEmpty
    }
}

Describe "Per-file syntax check" {
    $testCases = $script:ps1Files | ForEach-Object {
        @{ Name = $_.Name; Path = $_.FullName }
    }

    It "<Name> parses without errors" -TestCases $testCases {
        param($Name, $Path)
        $parseErrors = @()
        $null = [System.Management.Automation.Language.Parser]::ParseFile(
            $Path, [ref]$null, [ref]$parseErrors
        )
        if ($parseErrors) {
            $parseErrors | ForEach-Object {
                Write-Host "  [line $($_.Extent.StartLineNumber)] $($_.Message)" -ForegroundColor Red
            }
        }
        $parseErrors.Count | Should -Be 0
    }
}
