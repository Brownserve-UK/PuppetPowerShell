<#
.SYNOPSIS
    Disables the Puppet service on a machine
.DESCRIPTION
    Very basic function for quickly disabling the Puppet service on a machine.
.EXAMPLE
    PS C:\> Disable-PuppetService

    This would disable the Puppet service on the local machine and make sure it is stopped
.NOTES
    This is a very simple cmdlet made purely for convenience and is rather rough around the edges.
    The primary use case is for quickly stopping Puppet on a system to make sure it doesn't overwrite local changes.
#>
function Disable-PuppetService
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
        if ($Service.StartupType -ne 'Disabled')
        {
            Write-Verbose "Disabling service"
            Set-Service -Name $ServiceName -StartupType Disabled
        }
        if ($Service.Status -eq 'Running')
        {
            Write-Verbose "Service is running, stopping"
            Stop-Service $ServiceName
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
        if ($Service)
        {
            # This should stop and disable the daemon all in one I believe...
            & sudo launchctl unload -w /Library/LaunchDaemons/com.puppetlabs.puppet.plist
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
        & systemctl disable $ServiceName
    }
}