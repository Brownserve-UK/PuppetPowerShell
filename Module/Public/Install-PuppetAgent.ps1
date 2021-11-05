<#
.SYNOPSIS
    Installs Puppet agent on a machine
.DESCRIPTION
    Installs the requested version of Puppet agent for your operating system.
    You can either specify the major version that you want installed whereby the latest version for that release will be installed,
    or you can specify a specific version. (e.g. 6.10.2)
.EXAMPLE
    PS C:\> <example usage>
    Explanation of what the example does
.INPUTS
    Inputs (if any)
.OUTPUTS
    Output (if any)
.NOTES
    General notes
#>
function Install-PuppetAgent
{
    [CmdletBinding()]
    param
    (
        # The major version of Puppet agent to install
        [Parameter(Mandatory = $false)]
        [int]
        $MajorVersion,

        # The specific version of Puppet agent to install
        [Parameter(Mandatory = $false)]
        [version]
        $ExactVersion
    )
    
    begin
    {
        if (!$MajorVersion -and !$ExactVersion)
        {
            throw "One of 'MajorVersion' or 'ExactVersion' must be specified"
        }
        if ($MajorVersion -and $ExactVersion)
        {
            Write-Warning "Both 'MajorVersion' and 'ExactVersion' specified, only 'ExactVersion' will be used."
        }
        if ($ExactVersion)
        {
            [int]$MajorVersion = $ExactVersion.Major
        }
    }
    
    process
    {
        # macOS install method
        if ($IsMacOS)
        {
            Write-Verbose "Installing Puppet-Agent for macOS"
            $RootCheck = & id -u
            try
            {
                $BrewCheck = Get-Command 'brew'
            }
            catch {}
            if ($BrewCheck -and !$ExactVersion)
            {
                Write-Verbose "Using homebrew"
                if ($RootCheck -eq 0)
                {
                    throw "Running as root, this will not work with homebrew."
                }
                # In cases where we don't want an exact version _and_ homebrew is available we'll install using that
                # See here for more info https://github.com/puppetlabs/homebrew-puppet
                $Cask = "puppetlabs/puppet/puppet-agent-$MajorVersion"
                Write-Verbose "Installing $Cask"
                & brew install $Cask
                if ($LASTEXITCODE -ne 0)
                {
                    throw "Failed to install Puppet using brew"
                }
            }
            if (!$BrewCheck -or $ExactVersion)
            {
                Write-Warning "Homebrew not installed or exact version specified, falling back to legacy method"
                if ($RootCheck -ne 0)
                {
                    throw "Legacy install method requires root on macOS"
                }
                [version]$OSVersion = & sw_vers -productVersion
                if (!$OSVersion)
                {
                    throw "Failed to determine macOS version"
                }
                Write-Verbose "macOS version is $OSVersion"
                $BaseURL = "http://downloads.puppet.com/mac/puppet$($MajorVersion)"
                Write-Verbose "Querying $BaseURL for supported operating systems"
                # Get the contents of that folder and see if we can find a match for our OS version
                try
                {
                    $SupportedOS = Invoke-WebRequest $BaseURL | Select-Object -ExpandProperty Links
                }
                catch
                {
                    throw "Failed to query $BaseURL.`n$($_.Exception.Message)"
                }

                if (!$SupportedOS)
                {
                    throw "No results returned from $BaseURL"
                }

                # See if our OS is compatible...
                foreach ($Link in $SupportedOS.href)
                {
                    # Try getting the most exact version we can find
                    switch ($Link)
                    {
                        "$($OSversion.Major)/"
                        {
                            $MatchedVersion = "$($OSversion.Major)/"
                        }
                        "$($OSversion.Major).$($OSVersion.Minor)/"
                        {
                            $MatchedVersion = "$($OSversion.Major).$($OSVersion.Minor)/"
                        }
                    }
                    # Break out of the loop when we've found a match!
                    if ($MatchedVersion)
                    {
                        Write-Verbose "Matched '$MatchedVersion'"
                        break
                    }
                }
                if (!$MatchedVersion)
                {
                    throw "Unable to find a supported version of Puppet agent for macOS $($OSVersion.toString())"
                }
                # Only support x86_64 at present
                $BaseURL = $BaseURL + "/$MatchedVersion" + "x86_64"

                # Grab the exact version if we've specified one otherwise just get latest
                if ($ExactVersion)
                {
                    $DownloadURL = $BaseURL + "/puppet-agent-$($ExactVersion.ToString())-1.osx$($MatchedVersion -replace '\/','').dmg"
                }
                else
                {
                    $DownloadURL = $BaseURL + "/puppet-agent-latest.dmg"
                }

                # Download it
                $TempFile = Join-Path (Get-PSDrive Temp).Root 'puppet-agent.dmg'
                Write-Verbose "Downloading from $DownloadURL to $TempFile"
                try
                {
                    Invoke-WebRequest $DownloadURL -OutFile $TempFile
                }
                catch
                {
                    throw "Failed to download Puppet agent from $DownloadURL.`n$($_.Exception.Message)"
                }
                Write-Verbose "Mounting $TempFile"
                & hdiutil mount $TempFile -quiet
                if ($LASTEXITCODE -ne 0)
                {
                    throw "Failed to mount $TempFile"
                }
                try
                {
                    $PuppetDrive = Get-ChildItem '/Volumes/' | Where-Object { $_.Name -like 'puppet-agent*' }
                }
                catch
                {
                    throw "Failed to query Puppet drive.`n$($_.Exception.Message)"
                }
                if ($PuppetDrive.count -gt 1)
                {
                    throw "Too many Puppet drives returned!`nExpected 1 got $($PuppetDrive.count).`n$($PuppetDrive.PSPath)"
                }
                if (!$PuppetDrive)
                {
                    throw "No Puppet drives found"
                }
                # Get the pkg
                $PuppetPKG = Get-ChildItem $PuppetDrive | Where-Object { $_.Name -like '*.pkg' } | Select-Object -ExpandProperty 'PSPath' | Convert-Path
                if (!$PuppetPKG)
                {
                    # Clean-up
                    & hdiutil unmount $PuppetDrive -force -quiet
                    throw "Cannot find Puppet agent pkg installer"
                }
                Write-Verbose "Installing $PuppetPKG"
                & installer -pkg $PuppetPKG -target /
                if ($LASTEXITCODE -ne 0)
                {
                    # Clean-up
                    & hdiutil unmount $PuppetDrive -force -quiet
                    throw "Failed to install Puppet agent"
                }
                # Clean-up
                & hdiutil unmount $PuppetDrive -force -quiet
            }
        }
        # Windows install method
        if ($IsWindows)
        {
            $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
            $Administrator = $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
            if (!$Administrator)
            {
                throw "Must be run as administrator"
            }
            try
            {
                $ChocoCheck = Get-Command 'choco'
            }
            catch {}
            if ($ChocoCheck)
            {
                if (!$ExactVersion)
                {
                    # If we've only specified the major version then we need to do some work
                    # Get all versions of the package
                    $AvailableVersions = (& choco list -e puppet-agent -a -r) -replace 'puppet-agent\|', ''

                    # As it stands the latest version is always first in the array
                    $VersionToInstall = $AvailableVersions[0]
                    Write-Verbose "Latest versions appears to be $VersionToInstall"
                }
                else
                {
                    $VersionToInstall = $ExactVersion.ToString()
                }
                Write-Verbose "Attempting to install $VersionToInstall"
                & choco install 'puppet-agent' --version $VersionToInstall
                if ($LASTEXITCODE -ne 0)
                {
                    throw "Failed to install Puppet agent"
                }
            }
            else
            {
                Write-Warning "Chocolatey not available, falling back to legacy method"
                $BaseURL = "http://downloads.puppetlabs.com/windows/puppet$($MajorVersion)"

                if ($ExactVersion)
                {
                    $DownloadURL = $BaseURL + "/puppet-agent-$($ExactVersion.ToString())-x64.msi"
                }
                else
                {
                    $DownloadURL = $BaseURL + "/puppet-agent-x64-latest.msi"
                }

                # Download it
                $TempFile = Join-Path (Get-PSDrive Temp).Root 'puppet-agent.msi'
                Write-Verbose "Downloading from $DownloadURL to $TempFile"
                try
                {
                    Invoke-WebRequest -Uri $DownloadURL -OutFile $TempFile
                }
                catch
                {
                    throw "Failed to download Puppet agent.`n$($_.Exception.Message)"
                }

                # Install it
                & msiexec /qn /norestart /i $TempFile
            }
        }
        # Linux install method
        if ($IsLinux)
        {
            # We need to check if we're running as root
            $User = & id -u
            if ($User -ne 0)
            {
                throw "Must be run as root"
            }
            Write-Verbose "Checking distribution"
            $Distribution = & awk -F= '/^NAME/{print $2}' /etc/os-release
            if (!$Distribution)
            {
                throw "Unable to determine Linux distribution"
            }
            Write-Verbose "Linux distribution is $Distribution"
            switch -regex ($Distribution)
            {
                '\"CentOS Linux\"'
                {
                    Write-Verbose "Checking to see if Puppet agent is already installed."
                    $PuppetCheck = & yum list installed | Where-Object { $_ -like 'puppet-agent*' }
                    if ($PuppetCheck)
                    {
                        Write-Host "Puppet agent already installed:`n$PuppetCheck"
                        break
                    }
                    Write-Verbose "Installing Puppet agent for CentOS"
                    $CentOSVersion = (& awk -F= '/^VERSION_ID/{print $2}' /etc/os-release) -replace '\"', ''
                    $RepositoryURL = "https://yum.puppetlabs.com/puppet$MajorVersion-release-el-$CentOSVersion.noarch.rpm"
                    $TempFile = Join-Path (Get-PSDrive Temp).Root 'puppet.rpm'
                    Write-Verbose "Downloading from $RepositoryURL to $TempFile"
                    try
                    {
                        Invoke-WebRequest -Uri $RepositoryURL -OutFile $TempFile
                    }
                    catch
                    {
                        throw "Failed to download Puppet agent.`n$($_.Exception.Message)"
                    }
                    Write-Verbose "Installing from $TempFile"
                    & rpm -Uvh $TempFile
                    if ($LASTEXITCODE -ne 0)
                    {
                        throw "Failed to add yum repository."
                    }
                    Write-Verbose "Installing Puppet agent"
                    if ($ExactVersion)
                    {
                        & yum install puppet-agent-$ExactVersion -y
                    }
                    else
                    {
                        & yum install puppet-agent -y
                    }
                    if ($LASTEXITCODE -ne 0)
                    {
                        throw "Failed to install Puppet agent"
                    }
                }
                '\"(?:Ubuntu|Debian GNU/Linux)\"'
                {
                    # Do a quick check to see if Puppet is already installed
                    Write-Verbose "Checking to see if Puppet agent is already installed."
                    $PuppetCheck = & dpkg --get-selections | Where-Object { $_ -like 'puppet-agent*' }
                    if ($PuppetCheck)
                    {
                        Write-Host "Puppet agent is already installed on your system."
                        break
                    }
                    Write-Verbose "Installing Puppet agent for Debian based OS"
                    $ReleaseName = & lsb_release -c -s
                    $RepositoryURL = "http://apt.puppet.com/puppet$MajorVersion-release-$($ReleaseName).deb"
                    $TempFile = Join-Path (Get-PSDrive Temp).Root 'puppet.deb'
                    Write-Verbose "Downloading from $RepositoryURL to $TempFile"
                    try
                    {
                        Invoke-WebRequest -Uri $RepositoryURL -OutFile $TempFile
                    }
                    catch
                    {
                        throw "Failed to download Puppet repository.`n$($_.Exception.Message)"
                    }
                    Write-Verbose "Installing Puppet repository"
                    & dpkg -i $TempFile
                    if ($LASTEXITCODE -ne 0)
                    {
                        throw "Failed to install Puppet repository."
                    }
                    & apt-get update
                    Write-Verbose "Installing puppet-agent"
                    if ($ExactVersion)
                    {
                        # The packages seem to be in the format of "puppet-agent 6.24.0-1focal"
                        $VersionToInstall = "$ExactVersion-1$ReleaseName"
                        Write-Verbose "Installing $VersionToInstall"
                        & apt-get install -y puppet-agent=$VersionToInstall
                    }
                    else
                    {
                        Write-Verbose "Installing latest version"
                        & apt-get install -y puppet-agent
                    }
                    if ($LASTEXITCODE -ne 0)
                    {
                        throw "Failed to install Puppet agent"
                    }
                }
                Default 
                {
                    throw "Unsupported Linux distribution '$Distribution'"
                }
            }
        }
                
    }
    
    end
    {
        
    }
}