<#
.SYNOPSIS
    Initializes this repository
#>
# We require 6.0+ due to using newer features of PowerShell
#Requires -Version 6.0
[CmdletBinding()]
param (
    # If set will disable the compatible/incompatible cmdlet output at the end of the script
    [Parameter(
        Mandatory = $false
    )]
    [switch]
    $SuppressOutput
)
# Stop on errors
$ErrorActionPreference = 'Stop'

Write-Host 'Initialising repository, please wait...'

# We use this well-known global variable across a variety of projects for determining if given scripts/functions/cmdlets
# are compatible with the users operating system.
$Global:BrownserveCmdlets = @{
    CompatibleCmdlets   = @()
    IncompatibleCmdlets = @()
}

# If we're on Teamcity set the well-known $Global:CI variable, this is set on most other CI/CD providers but not Teamcity :(
if ($env:TEAMCITY_VERSION)
{
    Write-Verbose 'Running on Teamcity, setting $Global:CI'
    $env:CI = $true
}
    
# Suppress output on CI/CD - it's noisy
if ($env:CI)
{
    $SuppressOutput = $true
}

# Set up our permanent paths
# This directory is the root of the repo, it's handy to reference sometimes
$Global:RepoRootDirectory = (Resolve-Path (Get-Item $PSScriptRoot -Force).PSParentPath) | Convert-Path # -Force flag is needed to find dot folders on *.nix
# Holds all build related configuration along with this _init script
$Global:RepoBuildDirectory = Join-Path $global:RepoRootDirectory '.build' | Convert-Path
# Used to store any custom code/scripts/modules
$Global:RepoCodeDirectory = Join-Path $global:RepoRootDirectory '.build' 'code' | Convert-Path


# Set-up our ephemeral paths, that is those that will be destroyed and then recreated each time this script is called
$EphemeralPaths = @(
    ($RepoPackagesDirectory = Join-Path $Global:RepoRootDirectory 'packages'),
    ($RepoLogDirectory = Join-Path $global:RepoRootDirectory '.log'),
    ($RepoBuildOutputDirectory = Join-Path $global:RepoRootDirectory '.build' 'output'),
    ($RepoBinDirectory = Join-Path $global:RepoRootDirectory '.bin')

)
try
{
    Write-Verbose 'Recreating ephemeral paths'
    $EphemeralPaths | ForEach-Object {
        if ((Test-Path $_))
        {
            Remove-Item $_ -Recurse -Force | Out-Null
        }
        New-Item $_ -ItemType Directory -Force | Out-Null
    }
}
catch
{
    Write-Error $_.Exception.Message
    break
}

# Now that the ephemeral paths definitely exist we are free to set their global variables
# This is the directory that paket downloads stuff into
$Global:RepoPackagesDirectory = $RepoPackagesDirectory | Convert-Path 
# Used to store build logs and output from Start-SilentProcess
$global:RepoLogDirectory = $RepoLogDirectory | Convert-Path
# Used to store any output from builds (e.g. Terraform plans, MSBuild artifacts etc)
$global:RepoBuildOutputDirectory = $RepoBuildOutputDirectory | Convert-Path
# Used to store any downloaded binaries required for builds, cmdlets like Get-Vault make use of this variable
$global:RepoBinDirectory = $RepoBinDirectory | Convert-Path


# We use paket for managing our dependencies and we get that via dotnet
Write-Verbose "Restoring dotnet tools"
$DotnetOutput = & dotnet tool restore
if ($LASTEXITCODE -ne 0)
{
    $DotnetOutput
    throw "dotnet tool restore failed"
}

Write-Verbose "Installing paket dependencies"
$PaketOutput = & dotnet paket install
if ($LASTEXITCODE -ne 0)
{
    $PaketOutput
    throw "Failed to install paket dependencies"
}

# If Brownserve.PSTools is already loaded in this session (e.g. it's installed globally) we need to unload it
# This ensures only the expected version is available to us
if ((Get-Module 'Brownserve.PSTools'))
{
    try
    {
        Write-Verbose "Unloading Brownserve.PSTools"
        Remove-Module 'Brownserve.PSTools' -Force -Confirm:$false
    }
    catch
    {
        throw "Failed to unload Brownserve.PSTools.`n$($_.Exception.Message)"
    }
}
# Import the downloaded version of Brownserve.PSTools
try
{
    Write-Verbose "Importing Brownserve.PSTools module"
    Import-Module (Join-Path $Global:RepoPackagesDirectory 'Brownserve.PSTools' 'tools', 'Brownserve.PSTools.psd1') -Force -Verbose:$false
}
catch
{
    throw "Failed to import Brownserve.PSTools.`n$($_.Exception.Message)"
}

# Place any custom code below, this will be preserved whenever you update your _init script
### Start user defined _init steps
$global:RepoTestsDirectory = Join-Path $global:RepoRootDirectory '.build' 'tests' | Convert-Path
$global:RepoModuleDirectory = Join-Path $global:RepoRootDirectory 'Module' | Convert-Path
### End user defined _init steps

# If we're not suppressing output then we'll pipe out a list of cmdlets that are now available to the user along with
# Their synopsis. 
if (!$SuppressOutput)
{
    if ($Global:BrownserveCmdlets.CompatibleCmdlets)
    {
        Write-Host 'The following cmdlets are now available:'
        $Global:BrownserveCmdlets.CompatibleCmdlets | ForEach-Object {
            Write-Host "    $($_.Name) " -ForegroundColor Magenta -NoNewline; Write-Host "|  $($_.Synopsis)" -ForegroundColor Blue
        }
        Write-Host "For more information please use the 'Get-Help <command-name>' command`n"
    }
    if ($Global:BrownserveCmdlets.IncompatibleCmdlets)
    {
        Write-Warning 'The following cmdlets are not compatible with your operating system and have been disabled:'
        $Global:BrownserveCmdlets.IncompatibleCmdlets | ForEach-Object {
            Write-Host "  $($_.Name)" -ForegroundColor Yellow
        }
        '' # Blank line to break up output out a little
    }
}