param (
    # A CalVer string if you need to manually override the default yyyy.M.dHHmm version string.
    [string]$CalVer,
    # A prerelease tag to append to the module version (e.g., 'alpha', 'beta', 'rc1').
    [string]$Prerelease,
    [switch]$PublishToPSGallery,
    [string]$PSGalleryAPIPath,
    [string]$PSGalleryAPIKey
)

# The VS Code PowerShell Extension pre-loads PSScriptAnalyzer into the host
# process. PSPublishModule imports PSScriptAnalyzer internally, and loading a
# second copy of its assembly into the same appdomain throws an assembly-already-
# loaded error. Re-invoke in a clean pwsh -NoProfile child process to avoid it.
if ($Host.Name -eq 'Visual Studio Code Host' -or
    $null -ne [System.AppDomain]::CurrentDomain.GetAssemblies().Where({
            $_.GetName().Name -eq 'Microsoft.Windows.PowerShell.ScriptAnalyzer'
        }, 'First')[0]) {
    Write-Host 'Re-invoking in a clean pwsh process to avoid PSScriptAnalyzer assembly conflict...'
    $passThrough = @('-NoProfile', '-File', $PSCommandPath)
    if ($CalVer) { $passThrough += '-CalVer'; $passThrough += $CalVer }
    if ($Prerelease) { $passThrough += '-Prerelease'; $passThrough += $Prerelease }
    if ($PublishToPSGallery) { $passThrough += '-PublishToPSGallery' }
    if ($PSGalleryAPIPath) { $passThrough += '-PSGalleryAPIPath'; $passThrough += $PSGalleryAPIPath }
    if ($PSGalleryAPIKey) { $passThrough += '-PSGalleryAPIKey'; $passThrough += $PSGalleryAPIKey }
    & pwsh @passThrough
    exit $LASTEXITCODE
}

if (Get-Module -Name 'PSPublishModule' -ListAvailable) {
    Write-Information 'PSPublishModule is installed.'
} else {
    Write-Information 'PSPublishModule is not installed. Attempting installation.'
    try {
        Install-Module -Name Pester -AllowClobber -Scope CurrentUser -SkipPublisherCheck -Force
        Install-Module -Name PSScriptAnalyzer -Scope CurrentUser -Force
        Install-Module -Name PSPublishModule -AllowClobber -MaximumVersion 2.0.27 -Scope CurrentUser -Force
    } catch {
        Write-Error "PSPublishModule installation failed. $_"
    }
}

Import-Module -Name PSPublishModule -Force

$CopyrightYear = if ($Calver) { $CalVer.Split('.')[0] } else { (Get-Date -Format yyyy) }

Build-Module -ModuleName 'BlueTuxedo' {
    # Usual defaults as per standard module
    $Manifest = [ordered] @{
        ModuleVersion        = if ($Calver) { $CalVer } else { (Get-Date -Format yyyy.M.dHHmm -AsUTC) }
        CompatiblePSEditions = @('Desktop', 'Core')
        GUID                 = 'e98445b3-1d76-4a51-831d-ddfc7e0213fa'
        Author               = 'Jake Hildreth and Jim Sykora'
        Copyright            = "(c) 2023 - ${CopyrightYear}. All rights reserved."
        Description          = 'A tiny tool to identify and remediate common misconfigurations in Active Directory-Integrated DNS.'
        PowerShellVersion    = '5.1'
        ProjectUri           = 'https://github.com/jakehildreth/BlueTuxedo'
        Tags                 = @('Windows', 'BlueTuxedo', 'DNS', 'AD', 'ActiveDirectory', 'DomainNameSystem', 'ADIDNS')
    }
    if ($Prerelease) {
        $Manifest['Prerelease'] = $Prerelease
    }
    New-ConfigurationManifest @Manifest

    # Add standard module dependencies (directly, but can be used with loop as well)
    #New-ConfigurationModule -Type RequiredModule -Name 'PSSharedGoods' -Guid 'Auto' -Version 'Latest'

    # Add external module dependencies, using loop for simplicity
    # those modules are not available in PowerShellGallery so user has to have them installed
    $ExternalModules = @(
        # Required RSAT AD and DNS module
        'ActiveDirectory'
        'DhcpServer'
        'DnsServer'
        'DnsClient'
        'Microsoft.PowerShell.Security'
        # those modules are builtin in PowerShell so no need to install them
        # could as well be ignored with New-ConfigurationModuleSkip
        'Microsoft.PowerShell.Utility'
        'Microsoft.PowerShell.LocalAccounts'
        'Microsoft.PowerShell.Management'
        'Microsoft.WSMan.Management'
    )
    foreach ($Module in $ExternalModules) {
        New-ConfigurationModule -Type ExternalModule -Name $Module
    }

    New-ConfigurationModuleSkip -IgnoreFunctionName 'Clear-Host', 'Pause'

    $ConfigurationFormat = [ordered] @{
        RemoveComments                              = $false

        PlaceOpenBraceEnable                        = $true
        PlaceOpenBraceOnSameLine                    = $true
        PlaceOpenBraceNewLineAfter                  = $true
        PlaceOpenBraceIgnoreOneLineBlock            = $false

        PlaceCloseBraceEnable                       = $true
        PlaceCloseBraceNewLineAfter                 = $true
        PlaceCloseBraceIgnoreOneLineBlock           = $false
        PlaceCloseBraceNoEmptyLineBefore            = $true

        UseConsistentIndentationEnable              = $true
        UseConsistentIndentationKind                = 'space'
        UseConsistentIndentationPipelineIndentation = 'IncreaseIndentationAfterEveryPipeline'
        UseConsistentIndentationIndentationSize     = 4

        UseConsistentWhitespaceEnable               = $true
        UseConsistentWhitespaceCheckInnerBrace      = $true
        UseConsistentWhitespaceCheckOpenBrace       = $true
        UseConsistentWhitespaceCheckOpenParen       = $true
        UseConsistentWhitespaceCheckOperator        = $true
        UseConsistentWhitespaceCheckPipe            = $true
        UseConsistentWhitespaceCheckSeparator       = $true

        AlignAssignmentStatementEnable              = $true
        AlignAssignmentStatementCheckHashtable      = $true

        UseCorrectCasingEnable                      = $true
    }
    # format PSD1 and PSM1 files when merging into a single file
    # enable formatting is not required as Configuration is provided
    New-ConfigurationFormat -ApplyTo 'OnMergePSM1', 'OnMergePSD1' -Sort None @ConfigurationFormat
    # format PSD1 and PSM1 files within the module
    # enable formatting is required to make sure that formatting is applied (with default settings)
    New-ConfigurationFormat -ApplyTo 'DefaultPSD1', 'DefaultPSM1' -EnableFormatting -Sort None
    # when creating PSD1 use special style without comments and with only required parameters
    New-ConfigurationFormat -ApplyTo 'DefaultPSD1', 'OnMergePSD1' -PSD1Style 'Minimal'

    # configuration for documentation, at the same time it enables documentation processing
    New-ConfigurationDocumentation -Enable:$false -StartClean -UpdateWhenNew -PathReadme 'Docs\Readme.md' -Path 'Docs'

    New-ConfigurationImportModule -ImportSelf -ImportRequiredModules

    New-ConfigurationBuild -Enable:$true -SignModule:$false -DeleteTargetModuleBeforeBuild -MergeModuleOnBuild -UseWildcardForFunctions

    $PreScriptMerge = {
        param (
            # DNS server(s) to exclude from checks.
            [string[]]$Exclude
        )

    }

    $PostScriptMerge = {

        if ($Exclude) {
            $BTData = Invoke-BlueTuxedo -Exclude $Exclude -ExportCollectedData -ExportTestedData
        } else {
            $BTData = Invoke-BlueTuxedo -ExportCollectedData -ExportTestedData
        }
        $BTData
    }

    # New-ConfigurationArtefact -Type Packed -Enable -Path "$PSScriptRoot\..\Artefacts\Packed" -ArtefactName '<ModuleName>.zip'
    New-ConfigurationArtefact -Type Script -Enable -Path "$PSScriptRoot\..\Artefacts\Script" -PreScriptMerge $PreScriptMerge -PostScriptMerge $PostScriptMerge -ScriptName 'Invoke-<ModuleName>.ps1'
    New-ConfigurationArtefact -Type ScriptPacked -Enable -Path "$PSScriptRoot\..\Artefacts\ScriptPacked" -ArtefactName 'Invoke-<ModuleName>.zip' -PreScriptMerge $PreScriptMerge -PostScriptMerge $PostScriptMerge -ScriptName 'Invoke-<ModuleName>.ps1'
    # New-ConfigurationArtefact -Type Unpacked -Enable -Path "$PSScriptRoot\..\Artefacts\Unpacked"
    if ($PublishToPSGallery) {
        if ($PSGalleryAPIKey) {
            # API key passed directly (CI)
            New-ConfigurationPublish -Type PowerShellGallery -ApiKey $PSGalleryAPIKey -Enabled:$true
        } elseif ($PSGalleryAPIPath) {
            # API key read from a file (local development)
            New-ConfigurationPublish -Type PowerShellGallery -FilePath $PSGalleryAPIPath -Enabled:$true
        } else {
            Write-Error 'PublishToPSGallery specified but neither PSGalleryAPIKey nor PSGalleryAPIPath provided.'
        }
    }
}

Copy-Item "$PSScriptRoot\..\Artefacts\Script\Invoke-BlueTuxedo.ps1" "$PSScriptRoot\..\"

# Suppress validation errors and cleanup
[void]$CalVer
[void]$Exclude
