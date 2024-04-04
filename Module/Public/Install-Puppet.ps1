<#
.SYNOPSIS
    Installs Puppet tooling on a machine
.DESCRIPTION
    Installs the requested version of Puppet agent/server/bolt for your operating system.
    You can either specify the major version that you want installed whereby the latest version for that release will be installed,
    or you can specify a specific version. (e.g. 6.10.2)
.EXAMPLE
    Install-Puppet -MajorVersion 6

    This would install the latest version of Puppet 6 agent for your operating system.
.EXAMPLE
    Install-Puppet -ExactVersion 6.10.2 -Application 'puppetserver'

    This would install Puppet server 6.10.2 for your operating system.
.EXAMPLE
    Install-Puppet -Application 'puppet-bolt'

    This would install the latest version of Puppet bolt for your operating system.
#>
function Install-Puppet
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
        $ExactVersion,

        # Whether to install Puppet server or Puppet agent
        [Parameter(Mandatory = $false)]
        [string]
        [ValidateSet('puppet-agent', 'puppetserver', 'puppet-bolt')]
        $Application = 'puppet-agent',

        # Useful in testing to disable package managers
        [Parameter(DontShow)]
        [switch]
        $UseLegacyMethod
    )

    begin
    {
        if ($Application -eq 'puppetserver')
        {
            if (!$IsLinux)
            {
                Throw 'Puppet server is only available on Linux'
            }
        }
        # We only care about the versioning of Puppet server/agent
        if (!$MajorVersion -and !$ExactVersion -and ($Application -ne 'puppet-bolt'))
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
            Write-Verbose "Installing $Application for macOS"
            # This should work with both the legacy and Homebrew methods
            $PuppetCheck = pkgutil --pkgs | Where-Object { $_ -like "*$Application*" }
            if ($PuppetCheck)
            {
                Write-Host "$Application is already installed:`n$($PuppetCheck)"
                $InstallApplication = $false
            }
            if ($InstallApplication)
            {
                $RootCheck = & id -u
                try
                {
                    $BrewCheck = Get-Command 'brew'
                }
                catch {}
                if ($BrewCheck -and !$ExactVersion -and !$UseLegacyMethod)
                {
                    Write-Verbose 'Using homebrew'
                    if ($RootCheck -eq 0)
                    {
                        throw 'Running as root, this will not work with homebrew.'
                    }
                    # In cases where we don't want an exact version _and_ homebrew is available we'll install using that
                    # See here for more info https://github.com/puppetlabs/homebrew-puppet
                    if ($Application -eq 'puppet-bolt')
                    {
                        $Cask = "puppetlabs/puppet/$Application"
                    }
                    else
                    {
                        $Cask = "puppetlabs/puppet/$Application-$MajorVersion"
                    }
                    Write-Verbose "Installing $Cask"
                    & brew install $Cask
                    if ($LASTEXITCODE -ne 0)
                    {
                        throw "Failed to install $Application using brew"
                    }
                }
                <#
                When homebrew is not available or we require a specific version we'll need to query the pupetlabs downloads
                We do this by scrubbing the links at http://downloads.puppet.com/mac/ which isn't foolproof but should be good enough
             #>
                if (!$BrewCheck -or $ExactVersion -or $UseLegacyMethod)
                {
                    Write-Warning 'Homebrew not installed or exact version specified, falling back to legacy method'
                    if ($RootCheck -ne 0)
                    {
                        throw 'Legacy install method requires root on macOS'
                    }
                    [version]$OSVersion = & sw_vers -productVersion
                    if (!$OSVersion)
                    {
                        throw 'Failed to determine macOS version'
                    }
                    Write-Verbose "macOS version is $OSVersion"
                    if ($Application -eq 'puppet-agent')
                    {
                        $BaseURL = "http://downloads.puppet.com/mac/puppet$($MajorVersion)"
                    }
                    else
                    {
                        $BaseURL = 'http://downloads.puppet.com/mac/puppet-tools'
                    }
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
                    $BaseURL = $BaseURL + "/$MatchedVersion" + 'x86_64'

                    # Grab the exact version if we've specified one otherwise just get latest
                    if ($ExactVersion)
                    {
                        $DownloadURL = $BaseURL + "/$Application-$($ExactVersion.ToString())-1.osx$($MatchedVersion -replace '\/','').dmg"
                    }
                    else
                    {
                        $DownloadURL = $BaseURL + "/$Application-latest.dmg"
                    }

                    # Download it
                    $TempFile = Join-Path (Get-PSDrive Temp).Root "$Application.dmg"
                    Write-Verbose "Downloading from $DownloadURL to $TempFile"
                    try
                    {
                        Invoke-WebRequest $DownloadURL -OutFile $TempFile
                    }
                    catch
                    {
                        throw "Failed to download $Application from $DownloadURL.`n$($_.Exception.Message)"
                    }
                    Write-Verbose "Mounting $TempFile"
                    & hdiutil mount $TempFile -quiet
                    if ($LASTEXITCODE -ne 0)
                    {
                        throw "Failed to mount $TempFile"
                    }
                    try
                    {
                        $PuppetDrive = Get-ChildItem '/Volumes/' | Where-Object { $_.Name -like "$Application*" }
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
                        throw 'No Puppet drives found'
                    }
                    # Get the pkg
                    $PuppetPKG = Get-ChildItem $PuppetDrive | Where-Object { $_.Name -like '*.pkg' } | Select-Object -ExpandProperty 'PSPath' | Convert-Path
                    if (!$PuppetPKG)
                    {
                        # Clean-up
                        & hdiutil unmount $PuppetDrive -force -quiet
                        throw "Cannot find $Application pkg installer"
                    }
                    Write-Verbose "Installing $PuppetPKG"
                    & installer -pkg $PuppetPKG -target /
                    if ($LASTEXITCODE -ne 0)
                    {
                        # Clean-up
                        & hdiutil unmount $PuppetDrive -force -quiet
                        throw "Failed to install $Application"
                    }
                    # Clean-up
                    & hdiutil unmount $PuppetDrive -force -quiet
                }
            }
        }
        # Windows install method
        if ($IsWindows)
        {
            $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
            $Administrator = $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
            if (!$Administrator)
            {
                throw 'Must be run as administrator'
            }
            switch ($Application)
            {
                'puppet-agent'
                {
                    $Command = 'puppet'
                }
                'puppet-bolt'
                {
                    $Command = 'bolt'
                }
            }
            $PuppetCheck = Get-Command $Command -ErrorAction SilentlyContinue
            if ($PuppetCheck)
            {
                Write-Host "$Application is already installed:`n$($PuppetCheck.Source)"
                $InstallApplication = $false
            }
            if ($InstallApplication)
            {
                try
                {
                    $ChocoCheck = Get-Command 'choco'
                }
                catch {}
                if ($ChocoCheck -and !$UseLegacyMethod)
                {
                    if ($ExactVersion)
                    {
                        $VersionToInstall = $ExactVersion.ToString()
                    }
                    else
                    {
                        if ($MajorVersion)
                        {
                            # If we've only specified the major version then we need to do some work
                            # Get all versions of the package
                            $AvailableVersions = (& choco list -e $Application -a -r) -replace "$Application\|", ''
                            # Cast to version array
                            $AvailableVersionNumbers = $AvailableVersions | ForEach-Object { [version]$_ }
                            if (!$AvailableVersionNumbers)
                            {
                                throw "Failed to get available versions of $Application. This is quite possibly due to a bug in Chocolatey, try running 'choco upgrade chocolatey' to see if this fixes the problem."
                            }


                            # As it stands the latest version is always first in the array
                            try
                            {
                                $VersionToInstall = ($AvailableVersionNumbers | Where-Object { $_.Major -eq $MajorVersion } | Select-Object -First 1).ToString()

                            }
                            catch
                            {
                                throw "Failed to find a version to install.`n$($_.Exception.Message)"
                            }
                            if (!$VersionToInstall)
                            {
                                throw 'Cannot find a version to install.'
                            }
                            Write-Verbose "Latest version appears to be $VersionToInstall"
                        }
                    }
                    Write-Verbose "Attempting to install $Application"
                    if ($VersionToInstall)
                    {
                        & choco install $Application --version $VersionToInstall -y
                    }
                    else
                    {
                        & choco install $Application -y
                    }
                    if ($LASTEXITCODE -ne 0)
                    {
                        throw "Failed to install $Application"
                    }
                }
                else
                {
                    Write-Warning 'Chocolatey not available, falling back to legacy method'
                    if ($Application -eq 'puppet-agent')
                    {
                        $BaseURL = "http://downloads.puppetlabs.com/windows/puppet$($MajorVersion)"
                    }
                    else
                    {
                        $BaseURL = 'http://downloads.puppetlabs.com/windows/puppet-tools'
                    }

                    if ($ExactVersion)
                    {
                        $DownloadURL = $BaseURL + "/$Application-$($ExactVersion.ToString())-x64.msi"
                    }
                    else
                    {
                        $DownloadURL = $BaseURL + "/$Application-x64-latest.msi"
                    }

                    # Download it
                    $TempFile = Join-Path (Get-PSDrive Temp).Root "$Application.msi"
                    Write-Verbose "Downloading from $DownloadURL to $TempFile"
                    try
                    {
                        Invoke-WebRequest -Uri $DownloadURL -OutFile $TempFile
                    }
                    catch
                    {
                        throw "Failed to download $Application.`n$($_.Exception.Message)"
                    }

                    # Install it
                    Write-Verbose "Installing from $TempFile"
                    # Use start process so we can wait for completion
                    $Install = Start-Process 'msiexec' -ArgumentList "/qn /norestart /i $TempFile" -Wait -NoNewWindow -PassThru
                    if ($Install.ExitCode -ne 0)
                    {
                        throw "Failed to install $Application"
                    }
                }
            }
        }
        # Linux install method
        if ($IsLinux)
        {
            # We need to check if we're running as root
            $User = & id -u
            if ($User -ne 0)
            {
                throw 'Must be run as root'
            }
            Write-Verbose 'Checking distribution'
            $Distribution = & awk -F= '/^NAME/{print $2}' /etc/os-release
            if (!$Distribution)
            {
                throw 'Unable to determine Linux distribution'
            }
            Write-Verbose "Linux distribution is $Distribution"
            switch -regex ($Distribution)
            {
                '\"CentOS Linux\"'
                {
                    Write-Verbose "Checking to see if $Application is already installed."
                    $PuppetCheck = & yum list installed | Where-Object { $_ -like "$Application*" }
                    if ($PuppetCheck)
                    {
                        Write-Host "$Application already installed:`n$PuppetCheck"
                        $InstallApplication = $false
                    }
                    if ($InstallApplication)
                    {
                        if ($Application -eq 'puppetserver')
                        {
                            # We need to make sure we have git and ruby installed
                            & yum install -y git ruby
                            if ($LASTEXITCODE -ne 0)
                            {
                                throw 'Failed to install git and ruby'
                            }
                        }
                        Write-Verbose "Installing $Application for CentOS"
                        $CentOSVersion = (& awk -F= '/^VERSION_ID/{print $2}' /etc/os-release) -replace '\"', ''
                        if ($Application -eq 'puppet-bolt')
                        {
                            $RepositoryURL = "https://yum.puppet.com/puppet-tools-release-el-$CentOSVersion.noarch.rpm"
                        }
                        else
                        {
                            $RepositoryURL = "https://yum.puppetlabs.com/puppet$MajorVersion-release-el-$CentOSVersion.noarch.rpm"
                        }
                        $TempFile = Join-Path (Get-PSDrive Temp).Root 'puppet.rpm'
                        Write-Verbose "Downloading from $RepositoryURL to $TempFile"
                        try
                        {
                            Invoke-WebRequest -Uri $RepositoryURL -OutFile $TempFile
                        }
                        catch
                        {
                            throw "Failed to download $Application.`n$($_.Exception.Message)"
                        }
                        Write-Verbose "Installing from $TempFile"
                        & rpm -Uvh $TempFile
                        if ($LASTEXITCODE -ne 0)
                        {
                            throw 'Failed to add yum repository.'
                        }
                        Write-Verbose "Installing $Application"
                        if ($ExactVersion)
                        {
                            & yum install $Application-$ExactVersion -y
                        }
                        else
                        {
                            & yum install $Application -y
                        }
                        if ($LASTEXITCODE -ne 0)
                        {
                            throw "Failed to install $Application"
                        }
                    }
                }
                '\"(?:Ubuntu|Debian GNU/Linux)\"'
                {
                    # Do a quick check to see if Puppet is already installed
                    Write-Verbose "Checking to see if $Application is already installed."
                    $PuppetCheck = & dpkg --get-selections | Where-Object { $_ -like "$Application*" }
                    if ($PuppetCheck)
                    {
                        Write-Host "$Application is already installed on your system."
                        $InstallApplication = $false
                    }
                    if ($InstallApplication)
                    {
                        if ($Application -eq 'puppetserver')
                        {
                            # We need to make sure we have git and ruby installed
                            & apt-get install -y git ruby
                            if ($LASTEXITCODE -ne 0)
                            {
                                throw 'Failed to install git and ruby'
                            }
                        }
                        Write-Verbose "Installing $Application for Debian based OS"
                        try
                        {
                            Get-Command 'lsb_release' -ErrorAction Stop
                        }
                        catch
                        {
                            $InstallLSB = $true
                        }
                        if ($InstallLSB)
                        {
                            Write-Verbose 'lsb-release requires installation'
                            & apt-get install -y lsb-release
                            if ($LASTEXITCODE -ne 0)
                            {
                                throw 'Failed to install lsb-release'
                            }
                        }
                        $ReleaseName = & lsb_release -c -s
                        if ($Application -eq 'puppet-bolt')
                        {
                            $RepositoryURL = "http://apt.puppet.com/puppet-tools-release-$($ReleaseName).deb"
                        }
                        else
                        {
                            $RepositoryURL = "http://apt.puppet.com/puppet$MajorVersion-release-$($ReleaseName).deb"
                        }
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
                        Write-Verbose 'Installing Puppet repository'
                        & dpkg -i $TempFile
                        if ($LASTEXITCODE -ne 0)
                        {
                            throw 'Failed to install Puppet repository.'
                        }
                        & apt-get update
                        Write-Verbose "Installing $Application"
                        if ($ExactVersion)
                        {
                            # The packages seem to be in the format of "puppet-agent 6.24.0-1focal"
                            $VersionToInstall = "$ExactVersion-1$ReleaseName"
                            Write-Verbose "Installing $VersionToInstall"
                            & apt-get install -y $Application=$VersionToInstall
                        }
                        else
                        {
                            Write-Verbose 'Installing latest version'
                            & apt-get install -y $Application
                        }
                        if ($LASTEXITCODE -ne 0)
                        {
                            throw "Failed to install $Application"
                        }
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
