<#
.SYNOPSIS
    Sets Puppet configuration options.
.DESCRIPTION
    This cmdlet allows you to set Puppet configuration options en masse by supplying 
    a hash of configuration options.
    You can also choose the location of the puppet.conf file to use and a specific section to set
    the options under.
.EXAMPLE
    Set-PuppetConfigOption @{environment = 'production'}

    This would set the environment to 'production' in the puppet.conf file.
.NOTES
    Puppet does not validate the options your are setting are valid, and neither does this cmdlet.
#>
function Set-PuppetConfigOption
{
    [CmdletBinding()]
    param
    (
        # The option(s) to set
        [Parameter(Mandatory = $true)]
        [hashtable]
        $ConfigOptions,

        # The path to the configuration file (if not using the default)
        [Parameter(Mandatory = $false)]
        [string]
        $ConfigFilePath,

        # The section that you wish to set the options in (defaults to 'agent')
        [Parameter(Mandatory = $false)]
        [string]
        [ValidateSet('agent', 'main', 'master')]
        $Section = 'agent',

        # On *nix systems the 'puppet' command requires elevation, set this parameter to prefix the command with 'sudo'
        [Parameter(Mandatory = $false)]
        [switch]
        $Elevated
    )
    
    begin
    {
        
    }
    
    process
    {
        if ($IsWindows -or ($PSVersionTable.PSEdition -eq 'Desktop'))
        {
            if (!$ConfigFilePath)
            {
                $ConfigFilePath = 'C:\ProgramData\PuppetLabs\puppet\etc\puppet.conf'
            }
            $PuppetBin = Get-Command 'puppet' | Select-Object -ExpandProperty Source
            # No need to use 'sudo' on Windows
            $Elevated = $false
        }
        else
        {
            if (!$ConfigFilePath)
            {
                # AFAIK the puppet config file is in the same location on all Linux/macOS systems
                $ConfigFilePath = '/etc/puppetlabs/puppet/puppet.conf'
            }
            try
            {
                $PuppetBin = Get-Command 'puppet' | Select-Object -ExpandProperty Source
            }
            catch
            {
                # Don't raise an error, it's very common for Puppet to not be on the path
                Write-Verbose "Unable to find 'puppet' on the path, using default location"
            }
            # If all else fails, use a best guess!
            if (!$PuppetBin)
            {
                $PuppetBin = '/opt/puppetlabs/bin/puppet'
            }
        }
        if (!(Test-Path $PuppetBin))
        {
            throw "Could not find the puppet command at $PuppetBin"
        }
        if (!(Test-Path $ConfigFilePath))
        {
            throw "Could not find the puppet configuration file at $ConfigFilePath"
        }
        $ConfigOptions.GetEnumerator() | ForEach-Object {
            Write-Verbose "Now setting $($_.Key) = $($_.Value)"
            if ($Elevated)
            {
                & sudo $PuppetBin config set "$($_.Key)" "$($_.Value)" --config $ConfigFilePath --section $Section
            }
            else
            {
                & $PuppetBin config set "$($_.Key)" "$($_.Value)" --config $ConfigFilePath --section $Section
            }
            if ($LASTEXITCODE -ne 0)
            {
                Write-Error "Failed to set $($_.Key) to $($_.Value)"
            }
        }
    }
    
    end
    {
        
    }
}