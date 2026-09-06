BeforeAll {
    # Dot-source Install-Apps.ps1 with -DryRun and mocked external commands so the
    # main body is a no-op but the functions (Get-PrunePlan etc.) get defined.
    . "$PSScriptRoot\helpers\MockCommands.ps1"
    # Set-ExecutionPolicy throws on non-Windows; stub it so the dot-source works everywhere.
    function Set-ExecutionPolicy { param([Parameter(ValueFromRemainingArguments)] $rest) }
    . "$PSScriptRoot\..\installer\Install-Apps.ps1" -DryRun *> $null
}

Describe "Get-PrunePlan" {
    It "returns IDs present in Previous but absent from Current, per manager" {
        $prev = @{ winget = @('A', 'B', 'C'); choco = @('x', 'y'); npm = @(); uv = @() }
        $cur  = @{ winget = @('A', 'C');      choco = @('x', 'y'); npm = @(); uv = @() }

        $plan = Get-PrunePlan -Previous $prev -Current $cur

        $plan.winget | Should -Be @('B')
        $plan.choco  | Should -BeNullOrEmpty
        $plan.npm    | Should -BeNullOrEmpty
        $plan.uv     | Should -BeNullOrEmpty
    }

    It "returns nothing when the lists are identical" {
        $lists = @{ winget = @('A', 'B'); choco = @('x'); npm = @('n'); uv = @('u') }
        $plan  = Get-PrunePlan -Previous $lists -Current $lists

        @($plan.Values | ForEach-Object { $_ }).Count | Should -Be 0
    }

    It "treats a missing manager key as an empty list" {
        $prev = @{ winget = @('A') }
        $cur  = @{ }
        $plan = Get-PrunePlan -Previous $prev -Current $cur

        $plan.winget | Should -Be @('A')
        $plan.choco  | Should -BeNullOrEmpty
    }

    It "flags every previously-managed package when Current is empty" {
        $prev = @{ winget = @('A', 'B'); choco = @('x'); npm = @('n'); uv = @('u'); cargo = @('c') }
        $cur  = @{ winget = @();         choco = @();    npm = @();    uv = @();    cargo = @() }
        $plan = Get-PrunePlan -Previous $prev -Current $cur

        $plan.winget | Should -Be @('A', 'B')
        $plan.choco  | Should -Be @('x')
        $plan.npm    | Should -Be @('n')
        $plan.uv     | Should -Be @('u')
        $plan.cargo  | Should -Be @('c')
    }

    It "ignores blank entries in the previous list" {
        $prev = @{ winget = @('A', '', $null, 'B') }
        $cur  = @{ winget = @('A') }
        $plan = Get-PrunePlan -Previous $prev -Current $cur

        $plan.winget | Should -Be @('B')
    }
}
