#requires -Modules Pester
#Requires -Version 6.0
#.SYNOPSIS
#   Performs tests to make sure the Agent/Server installs work
Describe "Puppet installers" {
    # First we need to set-up our containers
    BeforeAll {
        $Dockerfiles = Get-ChildItem (Join-Path $global:RepoTestsDirectory 'containers' $global:OS) | Where-Object { $_.Name -match "Dockerfile" }
        $Dockerfiles | ForEach-Object {
            # Bit funky but allows us to catch nested Linux distributions
            $tag = "PuppetPowershell_$(Get-Item $_.PSParentPath -Force | Select-Object -ExpandProperty Name)".ToLower()
            & docker build -t $tag ($_.PSParentPath | Convert-Path)
            $script:Containers += $tag
        }
    }
}
Context "Puppet agent installer" {
    It "Should install on $global:OS" {

        {
            # on macOS we can't run the tests via Docker at the moment so use vagrant
            if ($IsMacOS)
            {
                Write-Verbose "macOS, using vagrant"
                $Vagrantfile = Get-ChildItem (Join-Path $global:RepoTestsDirectory 'Vagrant' 'Vagrantfile')
                Push-Location
                Set-Location $Vagrantfile.PSParentPath
                & vagrant up puppetagent-macos
                if ($LASTEXITCODE -ne 0)
                {
                    Pop-Location
                    throw "Failed to bring up Vagrant environment"
                }
                & vagrant ssh puppetagent-macos -c "pwsh -c 'Import-Module /usr/local/vagrant/Module/PuppetPowerShell.psm1 -Force; Install-Puppet -MajorVersion 6; Install-Puppet -Application puppet-bolt'"
                if ($LASTEXITCODE -ne 0)
                {
                    $ErrorMessage = "Failed to install Puppet agent on macOS"
                }
                & vagrant destroy -f
                Pop-Location
                if ($ErrorMessage)
                {
                    throw $ErrorMessage
                }
            }
            else
            {

                # Import the module and attempt to install Puppet agent!
                # we should try to param the version of Puppet to install
                $InstallScript = {
                    if ($IsWindows)
                    {
                        $ModulePath = "C:\module\PuppetPowerShell.psm1"
                    }
                    else
                    {
                        $ModulePath = '/module/PuppetPowerShell.psm1'
                    }
                    Import-Module $ModulePath -Force
                    if ($isLinux)
                    {
                        Install-Puppet -MajorVersion 6 -Application puppetserver
                    }
                    else
                    {
                        Install-Puppet -MajorVersion 6
                    }
                    Install-Puppet -Application puppet-bolt
                }
            
                $script:Containers | ForEach-Object {
                    # This volume mount will need tidying up for Windows containers...
                    & docker run --rm -v $global:RepoModuleDirectory/:/module $_ 'pwsh' '-Command' "$InstallScript"
                    # Do another test for exact version?
                    if ($LASTEXITCODE -ne 0)
                    {
                        throw "Failed to install Puppet agent on $_"
                    }
                }
            }
        } | Should -not -Throw 
    }
}