<#
.SYNOPSIS
  This contains the build tasks for Invoke-Build to use
#>
[CmdletBinding()]
param
(
    # If set to true this will denote a production release
    [Parameter(
        Mandatory = $False
    )]
    [bool]
    $PreRelease = $true,

    # The branch this is being built from
    [Parameter(
        Mandatory = $true
    )]
    [string]
    $BranchName,

    # The Nuget feeds to publish to
    [Parameter(
        Mandatory = $False
    )]
    [ValidateNotNullOrEmpty()]
    [array]
    $NugetFeedsToPublishTo,

    # The GitHub organisation/account to publish the release to
    [Parameter(
        Mandatory = $False
    )]
    [ValidateNotNullOrEmpty()]
    [string]
    $GitHubOrg,

    # The GitHub repo to publish the release to
    [Parameter(
        Mandatory = $False
    )]
    [ValidateNotNullOrEmpty()]
    [string]
    $GitHubRepo,

    # The PAT for pushing to GitHub
    [Parameter(
        Mandatory = $False
    )]
    [ValidateNotNullOrEmpty()]
    [string]
    $GitHubPAT,

    # The API key to use when publishing to a NuGet feed, this is always needed but may not always be used
    [Parameter(
        Mandatory = $False
    )]
    [string] $NugetFeedApiKey,

    # The API key to use when publishing to the PSGallery
    [Parameter(
        Mandatory = $False
    )]
    [string]
    $PSGalleryAPIKey
)
# Depending on how we got the branch name we may need to remove the full ref
$BranchName = $BranchName -replace 'refs\/heads\/', ''
Write-Verbose @"
`nBuild parameters:
    PreRelease = $PreRelease
    BranchName = $BranchName
    NugetFeedsToPublishTo = $($NugetFeedsToPublishTo -join ", ")
"@
$script:CurrentCommitHash = & git rev-parse HEAD


$global:BuiltModuleDirectory = Join-Path $global:RepoBuildOutputDirectory 'PuppetPowerShell'
$script:NugetPackageDirectory = Join-Path $global:RepoBuildOutputDirectory 'NuGetPackage'
$script:NuspecPath = Join-Path $script:NugetPackageDirectory 'PuppetPowerShell.nuspec'

# On non-windows platforms mono is required to run NuGet 🤢
$NugetCommand = 'nuget'
if (-not $isWindows)
{
    $NugetCommand = "mono"
}

# Synopsis: Generate version info from the changelog and branch name.
task GenerateVersionInfo {
    $script:Changelog = Read-Changelog -ChangelogPath (Join-Path $Global:RepoRootDirectory -ChildPath 'CHANGELOG.md')
    $script:Version = $Changelog.CurrentVersion
    $script:ReleaseNotes = $Changelog.ReleaseNotes -replace '"', '\"' -replace '`', '' -replace '\*','' # Filter out characters that'll break the XML and/or just generally look horrible in NuGet
    $NugetPackageVersionParams = @{
        Version = $Version
        BranchName = $BranchName
    }
    if ($PreRelease)
    {
        $NugetPackageVersionParams.Add('PreRelease',$true)
    }
    $script:NugetPackageVersion = New-NugetPackageVersion @NugetPackageVersionParams
    Write-Verbose "Version: $script:Version"
    Write-Verbose "Nuget package version: $script:NugetPackageVersion"
    Write-Verbose "Release notes:`n$script:ReleaseNotes"
}

# Synopsis: Checks to make sure we don't already have this release
task CheckPreviousRelease GenerateVersionInfo, {
    Write-Verbose "Checking for previous releases"
    $CurrentReleases = Get-GithubRelease `
        -GitHubToken $GitHubPAT `
        -RepoName $GitHubRepo `
        -GitHubOrg $GitHubOrg
    if ($CurrentReleases.tag_name -contains "v$script:NugetPackageVersion")
    {
        throw "There already appears to be a v$script:NugetPackageVersion release!`nDid you forget to update the changelog?"
    }
}

# Synopsis: Copies over all the necessary files to be packaged for a release
task CopyModule {
    Write-Verbose "Copying files to build output directory"
    # Copy the "Module" folder over to the build output folder under 'PuppetPowerShell'
    Copy-Item -Path $Global:RepoModuleDirectory -Destination $global:BuiltModuleDirectory -Recurse -Force
}

# Synopsis: Generates the module manifest
task GenerateModuleManifest CopyModule, {
    Write-Verbose "Creating PowerShell module manifest"
    # Get a list of Public cmdlets so we can mark them for export.
    $PublicScripts = Get-ChildItem (Join-Path $global:BuiltModuleDirectory 'Public') -Filter '*.ps1' -Recurse
    $PublicFunctions = $PublicScripts | ForEach-Object {
        $_.Name -replace '.ps1', ''
    }
    New-ModuleManifest `
        -Path (Join-Path $global:BuiltModuleDirectory -ChildPath 'PuppetPowerShell.psd1') `
        -Guid $Global:ModuleGUID `
        -Author 'ShoddyGuard' `
        -Copyright "$(Get-Date -Format yyyy) ShoddyGuard" `
        -CompanyName 'Brownserve UK' `
        -RootModule 'PuppetPowerShell.psm1' `
        -ModuleVersion "$script:Version" `
        -Description 'A collection of tools to aid in CI/CD deployments.' `
        -PowerShellVersion '6.0' `
        -ReleaseNotes $script:ReleaseNotes `
        -LicenseUri 'https://github.com/Brownserve-UK/PuppetPowerShell/blob/main/LICENSE' `
        -ProjectUri 'https://github.com/Brownserve-UK/PuppetPowerShell' `
        -Tags @('CI', 'CD') `
        -FunctionsToExport $PublicFunctions
    # If this is not a production release then update the fields accordingly
    if ($PreRelease)
    {
        Update-ModuleManifest `
            -Path (Join-Path $global:BuiltModuleDirectory -ChildPath 'PuppetPowerShell.psd1') `
            -Prerelease ($BranchName -replace '[^0-9A-Za-z]', '')
    }
}

# Synopsis: Creates our NuGet package
task CreateNugetPackage GenerateVersionInfo, GenerateModuleManifest, CopyModule, {
    # We'll copy our build module to the nuget package and rename it to 'tools'
    Write-Verbose "Copying built module into NuGet package"
    Copy-Item $global:BuiltModuleDirectory -Destination (Join-Path $script:NugetPackageDirectory 'tools') -Recurse
    # Copy each of the necessary files over to the build output directory
    $ItemsToCopy = @(
        (Join-Path $Global:RepoRootDirectory 'CHANGELOG.md'),
        (Join-Path $Global:RepoRootDirectory 'LICENSE'),
        (Join-Path $Global:RepoRootDirectory README.md)
    )
    Copy-Item $ItemsToCopy -Destination $script:NugetPackageDirectory -Force
    # Now we'll generate a nuspec file and pop it in the root of NuGet package
    Write-Verbose "Creating nuspec file"
    $Nuspec = @"
<?xml version="1.0" encoding="utf-8"?>
<package xmlns="http://schemas.microsoft.com/packaging/2011/08/nuspec.xsd">
  <metadata>
    <id>PuppetPowerShell</id>
    <version>$script:Version</version>
    <authors>Shoddy Guard</authors>
    <owners>Brownserve UK</owners>
    <requireLicenseAcceptance>false</requireLicenseAcceptance>
    <summary>A collection of tools for aiding in the deployment and management of Puppet tools.</summary>
    <description>A collection of tools for aiding in the deployment and management of Puppet tools.</description>
    <projectUrl>https://github.com/Brownserve-UK/PuppetPowerShell</projectUrl>
    <releaseNotes>$script:ReleaseNotes</releaseNotes>
    <readme>README.md</readme>
    <copyright>Copyright $(Get-Date -Format yyyy) ShoddyGuard.</copyright>
    <tags>PSMODULE CI CD</tags>
    <dependencies />
  </metadata>
</package>
"@
    New-Item $script:NuspecPath -Value $Nuspec -Force | Out-Null
    $script:NuspecPath = $script:NuspecPath | Convert-Path
}

# Synopsis: Create the nuget package
task Pack CreateNugetPackage, GenerateModuleManifest, {
    Write-Verbose "Creating NuGet package"
    exec {
        # Note: the paths must be a separate index to the switch in the array
        $NugetArguments = @(
            "pack",
            "$script:NuspecPath",
            "-NoPackageAnalysis",
            "-Version",
            "$NugetPackageVersion",
            "-OutputDirectory",
            "$Global:RepoBuildOutputDirectory"
        )
        # On *nix we need to use mono to invoke nuget, so fudge the arguments a bit
        if (-not $isWindows)
        {
            # Mono won't have access to our NuGet PowerShell alias, so set the path using our env var
            $NugetArguments = @($Global:NugetPath) + $NugetArguments
        }
        & $NugetCommand $NugetArguments
    }
    $script:nupkgPath = Join-Path $Global:RepoBuildOutputDirectory "PuppetPowerShell.$script:NugetPackageVersion.nupkg" | Convert-Path
}

# Synopsis: Performs some tests to make sure everything works as intended
task Tests Pack, {
    Write-Verbose "Performing unit testing, this may take a while..."
    $Results = Invoke-Pester -Path $Global:RepoTestsDirectory -PassThru
    assert ($results.FailedCount -eq 0) "$($results.FailedCount) test(s) failed."
}

# Synopsis: Push the package up to the feed(s)
task PushNuget CheckPreviousRelease, Tests, {
    foreach ($NugetFeedToPublishTo in $NugetFeedsToPublishTo)
    {
        $NugetArguments = @(
            'push',
            $script:nupkgPath,
            '-Source',
            $NugetFeedsToPublishTo,
            '-ApiKey',
            $NugetFeedApiKey
        )
        if (-not $isWindows)
        {
            $NugetArguments = @($Global:NugetPath) + $NugetArguments
        }
        Write-Verbose "Pushing to $NugetFeedToPublishTo"
        # Be careful - Invoke-BuildExec requires curly braces to be on the same line!
        exec {
            & $NugetCommand $NugetArguments
        }
    }
}

# Synopsis: Push the module to PSGallery too
task PushPSGallery CheckPreviousRelease, Tests, {
    Write-Verbose "Pushing to PSGallery"
    # For PSGallery the module needs to be in a directory named after itself... -_- (PowerShellGet is awful)
    $PSGalleryParams = @{
        Path = $global:BuiltModuleDirectory
        NuGetAPIKey = $PSGalleryAPIKey
    }
    Publish-Module @PSGalleryParams
}

# Synopsis: Creates a GitHub release for this version, we only do this once we've had a successful NuGet push
task GitHubRelease PushNuget, PushPSGallery, {
    Write-Verbose "Creating GitHub release for $script:NugetPackageVersion"
    $ReleaseParams = @{
        Name        = "v$script:NugetPackageVersion"
        Tag         = "v$script:NugetPackageVersion"
        Description = $script:ReleaseNotes
        GitHubToken = $GitHubPAT
        RepoName    = $GitHubRepo
        GitHubOrg   = $GitHubOrg
    }
    if ($PreRelease)
    {
        $ReleaseParams.Add('Prerelease', $true)
        $ReleaseParams.Add('TargetCommit',$script:CurrentCommitHash)
    }
    New-GitHubRelease @ReleaseParams | Out-Null
}

# Synopsis: wrapper task to build the nupkg
task Build Pack, {}

# Synopsis: wrapper task to build then test the nupkg
task Test Tests, {}

# Synopsis: wrapper task to build, test then release the nupkg
task Release GitHubRelease, {}
