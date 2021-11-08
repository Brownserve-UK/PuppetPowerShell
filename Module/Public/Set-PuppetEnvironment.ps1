<#
.SYNOPSIS
    Sets the environment of a Puppet node
.DESCRIPTION
    Sets the environment of a Puppet node, either locally or remotely.
.EXAMPLE
    Set-PuppetEnvironment "dev"

    This would set the Puppet environment to "dev" for the current node
.EXAMPLE
    Set-PuppetEnvironment "dev" -ComputerName "mynode" -Credential (Get-Credential) -Communicator "WinRM"

    Will connect to mynode using WinRM and set the Puppet environment to "dev"

.EXAMPLE
    Set-PuppetEnvironment "dev" -ComputerName "mynode" -Credential (Get-Credential) -Communicator "SSH" -Elevated

    Will connect to mynode using SSH and set the Puppet environment to "dev" using an elevated account
.NOTES
    Remoting is very experimental at this time and may be removed in a future release.
    When remoting to Linux hosts you may wish to use SSH to ensure maximum compatibility.
    You'll need to make sure you have "Subsystem powershell /usr/bin/pwsh -sshs -NoLogo" in you sshd config.
    If others have more experience in this area then I am welcome to PR's!
#>
function Set-PuppetEnvironment
{
    [CmdletBinding()]
    param
    (
        # The environment to set
        [Parameter(Mandatory = $false)]
        [string]
        $Environment = 'production',

        # The computer name to set the environment for
        [Parameter(Mandatory = $false)]
        [string]
        $ComputerName,

        # Credentials to use for the remote connection
        [Parameter(Mandatory = $false)]
        [pscredential]
        $Credential,

        # When running on Linux it may be required to elevate privileges if you're not ssh'ing as root
        # Use this parameter to elevate privileges
        [Parameter(Mandatory = $false)]
        [switch]
        $Elevated,

        # The type of communicator to use (WinRM or SSH)
        [Parameter(Mandatory = $false)]
        [string]
        [ValidateSet('WinRM', 'ssh')]
        $Communicator = 'WinRM'
    )
    
    begin
    {
        
    }
    
    process
    {
        # Create a script to run either locally or remotely
        $ScriptToRun = {
            param 
            (
                [Parameter(Position = 0)]
                [string]
                $Environment,

                # Elevates the process to administrator privileges
                [Parameter(Position = 1)]
                [bool]
                $Elevated = $false
            )
            $ErrorActionPreference = 'Stop'
            # We can't always guarantee that we'll be connecting to a PowerShell 6.0+ host
            if ($IsWindows -or ($PSVersionTable.PSEdition -eq 'Desktop'))
            {
                $PuppetConfFile = 'C:\ProgramData\PuppetLabs\puppet\etc\puppet.conf'
                $PuppetBin = 'C:\ProgramData\PuppetLabs\puppet\bin\puppet.bat'
            }
            else
            {
                # AFAIK macOS and Linux all use the same locations
                $PuppetConfFile = '/etc/puppetlabs/puppet/puppet.conf'
                $PuppetBin = '/opt/puppetlabs/bin/puppet'
            }
            if (!(Test-Path $PuppetBin))
            {
                throw "Cannot find Puppet binary at $PuppetBin"
            }
            if (!(Test-Path $PuppetConfFile))
            {
                throw "Cannot find Puppet config file at $PuppetConfFile"
            }
            if ($Elevated -and (!$IsWindows -or ($PSVersionTable.PSEdition -ne 'Desktop')))
            {
                # On *nix we need to elevate privileges to run Puppet
                & sudo $PuppetBin config set --section agent environment $Environment --config $PuppetConfFile
            }
            else
            {
                & $PuppetBin config set --section agent environment $Environment --config $PuppetConfFile
            }
            if ($LASTEXITCODE -ne 0)
            {
                Write-Error "Failed to set the Puppet environment to $Environment"
            }
        }
        $InvokeParams = @{
            ScriptBlock = $ScriptToRun
        }
        $Arguments = @($Environment)
        if ($ComputerName)
        {
            if ($Communicator -eq 'ssh')
            {
                $InvokeParams.Add('HostName', $ComputerName)
            }
            else
            {
                $InvokeParams.Add('ComputerName', $ComputerName)
            }
        }
        if ($Credential)
        {
            if ($Communicator -eq 'ssh')
            {
                # Just take the username, I don't think it's currently possible to set the password for SSH
                $InvokeParams.Add('UserName', $Credential.UserName)
            }
            else
            {
                $InvokeParams.Add('Credential', $Credential)
            }
        }
        if ($Elevated)
        {
            $Arguments += @($true)
        }

        try
        {
            Invoke-Command @InvokeParams -ArgumentList $Arguments
        }
        catch
        {
            throw "Failed to set Puppet environment.`n$($_.Exception.Message)"
        }    
    }
    
    end
    {
        
    }
}