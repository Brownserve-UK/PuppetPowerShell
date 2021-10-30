<#
.SYNOPSIS
    Short description
.DESCRIPTION
    Long description
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
        if ($IsMacOS)
        {
            Write-Verbose "Installing Puppet-Agent for macOS"
            try
            {
                $BrewCheck = Get-Command 'brew'
            }
            catch
            {
                
            }
            if ($BrewCheck -and !$ExactVersion)
            {
                Write-Verbose "Using homebrew"
                # In cases where we don't want an exact version _and_ homebrew is available we'll install using that
                # See here for more info https://github.com/puppetlabs/homebrew-puppet
                $Cask = "puppetlabs/puppet/puppet-agent-$MajorVersion"
                & brew install $Cask
                if ($LASTEXITCODE -ne 0)
                {
                    throw "Failed to install Puppet using brew"
                }
            }

            if (!$BrewCheck -or $ExactVersion)
            {
                Write-Warning "Homebrew not installed or exact version specified, falling back to legacy method"
                $RootCheck = whoami
                if ($RootCheck -ne 'root')
                {
                    throw "Legacy install method requires root on macOS"
                }
                [version]$OSVersion = & sw_vers -productVersion
                if (!$OSVersion)
                {
                    throw "Failed to determine macOS version"
                }
                $BaseURL = "http://downloads.puppet.com/mac/puppet$($MajorVersion)"
                # Get the contents of that folder and see if we can find a match for our OS version
                $SupportedOS = Invoke-WebRequest $BaseURL | Select-Object -ExpandProperty Links

                if (!$SupportedOS)
                {
                    throw "TBC"
                }

                # Try getting the most exact version we can find
                switch ($SupportedOS.href)
                {
                    "$($OSversion.Major)/"
                    {
                        $MatchedVersion = "$($OSversion.Major)/"
                    }
                    "$($OSversion.Major).$($OSVersion.Minor)/"
                    {
                        $MatchedVersion = "$($OSversion.Major).$($OSVersion.Minor)/"
                    }
                    default
                    {
                        throw "Unable to find a supported version for macOS $($OSVersion.ToString())"
                    }
                }
                # Only support x86_64 at present
                $BaseURL = $BaseURL + "/$MatchedVersion" + "x86_84"

                # Grab the exact version if we've specified one otherwise just get latest
                if ($ExactVersion)
                {
                    $DownloadURL = $BaseURL + "/puppet-agent-$($ExactVersion.ToString())-1.osx$($MatchedVersion).dmg"
                }
                else
                {
                    $DownloadURL = $BaseURL + "/puppet-agent-latest.dmg"
                }

                # Download it
                Invoke-WebRequest $DownloadURL
            }
        }
    }
    
    end
    {
        
    }
}