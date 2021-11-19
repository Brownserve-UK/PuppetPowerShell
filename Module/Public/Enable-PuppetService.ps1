<#
.SYNOPSIS
    Enables the Puppet service on a machine
.DESCRIPTION
    Very basic function for quickly enabling the Puppet service at boot on a machine.
.EXAMPLE
    PS C:\> Enable-PuppetService

    This would enable the Puppet service on the local machine and make sure it is running
.NOTES
    This is a very simple cmdlet made purely for convenience and is rather rough around the edges.
    The intended use case is for reenabling the Puppet service after making changes to a local node.
#>
function Enable-PuppetService
{
    [CmdletBinding()]
    param
    (
        # The name of the Puppet service
        [Parameter(Mandatory = $false)]
        [string]
        $ServiceName = "puppet"
    )

    if ($IsWindows)
    {
        $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
        $Administrator = $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
        if (!$Administrator)
        {
            throw "Must be run as administrator"
        }
        $Service = Get-Service $ServiceName
        if ($Service.StartupType -eq 'Disabled')
        {
            Write-Verbose "Service is disabled, setting to start automatically"
            Set-Service -Name $ServiceName -StartupType Automatic
        }
        if ($Service.Status -ne 'Running')
        {
            Write-Verbose "Service is not running, starting"
            Start-Service $ServiceName
        }
    }
    if ($IsMacOS)
    {
        # We need to check if we're running as root
        $User = & id -u
        if ($User -ne 0)
        {
            throw "Must be run as root"
        }
        # Service seems to live here: /Library/LaunchDaemons/com.puppetlabs.puppet.plist
        $Service = & sudo launchctl list | Where-Object { $_ -like "*$ServiceName*" }
        if (!$Service)
        {
            # This should load and launch the daemon all in one I believe...
            & sudo launchctl load -w /Library/LaunchDaemons/com.puppetlabs.puppet.plist
        }
    }
    if ($IsLinux)
    {
        # We need to check if we're running as root
        $User = & id -u
        if ($User -ne 0)
        {
            throw "Must be run as root"
        }

        # Everything seems to use systemd these days
        & systemctl enable $ServiceName
    }
}