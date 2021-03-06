#requires -Modules Pester
#Requires -Version 6.0
#.SYNOPSIS
#   Performs tests to make sure the Agent/Server installs work
Describe "Puppet installers" {
    # First we need to set-up our containers
    BeforeAll {
        $global:Containers = @()
        $Dockerfiles = Get-ChildItem (Join-Path $global:RepoTestsDirectory 'Containers' $global:OS) -Recurse -Force | Where-Object { $_.Name -match "Dockerfile" }
        $Dockerfiles | ForEach-Object {
            # Bit funky but allows us to catch nested Linux distributions
            $tag = "PuppetPowershell_$(Get-Item $_.PSParentPath -Force | Select-Object -ExpandProperty Name)".ToLower()
            & docker build -t $tag ($_.PSParentPath | Convert-Path)
            if ($LASTEXITCODE -ne 0)
            {
                Write-Error "Failed to build container: $tag"
            }
            $global:Containers += $tag
        }
    }
    Context "Puppet agent installer" {
        It "Should install on $global:OS" {
            {
                # on macOS we can't run the tests via Docker at the moment so use vagrant
                if ($IsMacOS)
                {
                    # On Cloud based runners it's a real crapshoot if vagrant will work so just test locally
                    # (we don't care about what we do to a cloud runner!)
                    if ($env:CloudRunner)
                    {
                        try
                        {
                            Join-Path $global:BuiltModuleDirectory -ChildPath "PuppetPowerShell.psd1" | Import-Module -Force -Verbose:$false
                        }
                        catch
                        {
                            throw "Failed to import PuppetPowerShell module.`n$($_.Exception.Message)"
                        }
                        try 
                        {
                            # This should give a nice mix of tests
                            Install-Puppet -MajorVersion 6 -Application 'puppet-agent'
                            Install-Puppet -Application 'puppet-bolt'
                        }
                        catch 
                        {
                            throw "Failed to install tooling.`n$($_.Exception.Message)"
                        }
                    }
                    # If we're not running on a cloud provider then we don't want to pollute our local install so use vagrant
                    else
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
                }
                else
                {

                    # Import the module and attempt to install Puppet agent!
                    # we should try to param the version of Puppet to install
                    $InstallScript = {
                        if ($IsWindows)
                        {
                            $ModulePath = 'C:\module\PuppetPowerShell.psm1'
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
            
                    $global:Containers | ForEach-Object {
                        # This volume mount will need tidying up for Windows containers...
                        if ($null -eq $_)
                        {
                            throw "`$Containers appears to be null!"
                        }
                        if ($IsWindows)
                        {
                            $Volume = "$global:RepoModuleDirectory\:C:\module"
                        }
                        else
                        {
                            $Volume = "$global:RepoModuleDirectory/:/module"
                        }
                        & docker run --rm -v $Volume $_ 'pwsh' '-Command' "$InstallScript"
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
}