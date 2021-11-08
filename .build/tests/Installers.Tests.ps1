#requires -Modules Pester
#.SYNOPSIS
#   Performs tests to make sure the Agent/Server installs work
Describe "Puppet installers" {
    # First we need to set-up our containers
    BeforeAll {
        $Dockerfiles = Get-ChildItem (Join-Path $global:RepoTestsDirectory 'containers' $global:OS) | Where-Object { $_.Name -match "Dockerfile" }
        $Dockerfiles | ForEach-Object {
            $tag = "PuppetPowershell_$($_.Parent.Name)".ToLower()
            & docker build -t $tag ($_.PSParentPath | Convert-Path)
            $script:Containers += $tag
        }
    }
    Context "Puppet agent installer" {
        It "Should install on $global:OS" {

            # Import the module and attempt to install Puppet agent!
            # This will need tidying up for Windows and also we should try to param the version of Puppet to install
            $InstallScript = {
                Import-Module '/module/PuppetPowershell.psm1'
                Install-PuppetAgent -MajorVersion 6
            }
            
            $script:Containers | ForEach-Object {
                # This volume mount will need tidying up for Windows containers...
                & docker run --rm -v $global:RepoModuleDirectory/:/module $_ 'pwsh' '-Command' "$InstallScript"
                # Do another test for exact version?
            }
            $LASTEXITCODE | Should -eq 0
        }
    }
}