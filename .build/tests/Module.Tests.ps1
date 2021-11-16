#requires -Modules Pester
#.SYNOPSIS
#   Performs tests to make sure the PowerShell module works as intended
BeforeAll {
    # Remove the module we've already imported 😬
    $ModuleCheck = Get-Module | Where-Object { $_.Name -eq "PuppetPowerShell" }
    if ($ModuleCheck)
    {
        Remove-Module PuppetPowerShell -Verbose:$false
    }
}
Describe 'ModuleImport' {
    Context 'When PuppetPowerShell is imported' {
        It 'should not throw any exception' {
            { Join-Path $global:BuiltModuleDirectory -ChildPath "PuppetPowerShell.psd1" | Import-Module -Force -Verbose:$false } | Should -not -Throw 
        }
        It 'should have cmdlets on the path' -TestCases @(
            @{Filter = 'Install-Puppet'; Expected = 'Install-Puppet' }
        ) {
            param ($Filter, $Expected)
            $Commands = Get-Command -Name $Filter
            $Commands.Name | Should -Be $Expected
        }
    }
}