<#
.SYNOPSIS
    Contains PowerShell code to aid in Puppet deployments
#>
#Requires -Version 6.0
[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'

# We use some special variables for working out what cmdlets are compatible with a users systems
$PublicCmdlets = @()
$CompatibleCmdlets = @()
$IncompatibleCmdlets = @()

# Let's see if we've got the commands available in our path
try
{
    $AgentCheck = Get-Command 'puppet'
    $BoltCheck = Get-Command 'bolt'
    $ServerCheck = Get-Command 'puppetserver'
}
catch {}

# If not try to make best guesses as to where they will be
if (!$AgentCheck)
{
    if ($IsWindows)
    {
        $AgentPath = 'C:\ProgramData\PuppetLabs\puppet\bin\puppet.bat'
    }
    else
    {
        $AgentPath = '/opt/puppetlabs/bin/puppet'
    }
    try
    {
        $AgentCheck = Get-Command $AgentPath
    }
    catch {}
    if ($AgentCheck)
    {
        Set-Alias 'puppet' $AgentPath -Scope Global
    }
}
if (!$BoltCheck)
{
    if ($IsWindows)
    {
        $BoltPath = 'C:\ProgramData\PuppetLabs\bolt\bolt.bat'
    }
    else
    {
        $BoltPath = '/opt/puppetlabs/bin/bolt'
    }
    try
    {
        $BoltCheck = Get-Command $BoltPath
    }
    catch{}
    if ($BoltCheck)
    {
        Set-Alias 'bolt' $BoltPath -Scope Global
    }
}
if ($IsLinux)
{
    if (!$ServerCheck)
    {
        $ServerPath = '/opt/puppetlabs/bin/puppetserver'
        try
        {
            $ServerCheck = Get-Command $ServerPath
        }
        catch{}
    }
    if ($ServerCheck)
    {
        Set-Alias 'puppetserver' $ServerPath -Scope Global
    }
}

# Dot source our private functions so they are available for our public functions to use
# Join-Path $PSScriptRoot -ChildPath 'Private' |
#     Resolve-Path |
#         Get-ChildItem -Filter *.ps1 -Recurse |
#             ForEach-Object {
#                 . $_.FullName
#             }

# Dot source our public functions and then add their help information to an array
Join-Path $PSScriptRoot -ChildPath 'Public' |
    Resolve-Path |
        Get-ChildItem -Filter *.ps1 -Recurse |
            ForEach-Object {
                . $_.FullName
                $PublicCmdlets += Get-Help $_.BaseName
            }

# Go over the array we just created to see if all of our cmdlets/functions are compatible with the OS we are running
# If they are then we export it for use, if not then we do not.
$PublicCmdlets | ForEach-Object {
    $RegexMatch = [regex]::Match(($_.Description | Out-String), '\[Compatible with: (?<os>.*)\]')
    if ($RegexMatch.Success)
    {
        $CompatibleOS = $RegexMatch.Groups['os'] -split ', '
        # There are cases whereby we may want to ignore the compatibility check (such as generating help docs)
        # And export the function regardless.
        if ($global:IgnoreCmdletCompatibility)
        {
            $CompatibleOS = @('Windows', 'macOS', 'Linux')
        }
        if ($global:OS -in $CompatibleOS)
        {
            $CompatibleCmdlets += $_
        }
        else
        {
            $IncompatibleCmdlets += $_
        }
    }
    # If it doesn't have a [Compatible with: ] block then we just assume it's compatible with everything
    else
    {
        $CompatibleCmdlets += $_
    }
}

$CompatibleCmdlets | ForEach-Object {
    Export-ModuleMember $_.Name
}

<# 
   If our well known variables are present it means we're running as part of a build and we don't need to list
   our compatible/incompatible cmdlets.
#>
if ($Global:BrownserveCmdlets)
{
    $Global:BrownserveCmdlets.CompatibleCmdlets += $CompatibleCmdlets
    $Global:BrownserveCmdlets.IncompatibleCmdlets += $IncompatibleCmdlets
}
else
{
    Write-Host "The following cmdlets from $($MyInvocation.MyCommand) are now available for use:" -ForegroundColor White
    $CompatibleCmdlets | ForEach-Object {
        Write-Host "    $($_.Name) " -ForegroundColor Magenta -NoNewline; Write-Host "|  $($_.Synopsis)" -ForegroundColor Blue
    }
    Write-Host "For more information please use the 'Get-Help <command-name>' command`n"
    if ($IncompatibleCmdlets)
    {
        Write-Warning "The following cmdlets are NOT compatible with your OS and have been disabled:"
        $IncompatibleCmdlets | ForEach-Object {
            Write-Host "  $($_.Name)" -ForegroundColor Yellow
        }
        '' # Empty to line to break up output a little
    }
}