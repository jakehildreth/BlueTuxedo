function Invoke-BlueTuxedo {
    [CmdletBinding()]
    param (
        [string]$Forest = (Get-ADForest).Name,
        [string]$InputPath,
        [switch]$ShowSecurityDescriptors = $false,
        [string[]]$Exclude,
        [switch]$ExportCollectedData = $false,
        [switch]$ExportTestedData = $false,
        [switch]$Demo = $false
    )

    if ($Demo) { Clear-Host }
    $Module = $MyInvocation.MyCommand.Module
    $ModuleVersion = if ($Module) {
        $Prerelease = $Module.PrivateData.PSData.Prerelease
        if ($Prerelease) { "$($Module.Version)-$Prerelease" } else { "$($Module.Version)" }
    }
    Show-BTLogo -Version $ModuleVersion

    $Domains = Get-BTTarget -Forest $Forest -InputPath $InputPath

    #region Get Data
    Write-Host 'Please hold. Collecting DNS data from the following domains:' -ForegroundColor Green
    Write-Host $Domains.split(' ') -ForegroundColor Yellow

    Write-Verbose "[$(Get-Date -Format 'yyyy-MM-dd hh:mm:ss')] Collecting ADI Zones" -Verbose
    $ADIZones = Get-BTADIZone -Domains $Domains

    Write-Verbose "[$(Get-Date -Format 'yyyy-MM-dd hh:mm:ss')] Collecting Conditional Forwarders" -Verbose
    $ConditionalForwarders = Get-BTConditionalForwarder -Domains $Domains -Exclude $Exclude

    Write-Verbose "[$(Get-Date -Format 'yyyy-MM-dd hh:mm:ss')] Collecting Dangling SPNs" -Verbose
    $DanglingSPNs = Get-BTDanglingSPN -Domains $Domains

    Write-Verbose "[$(Get-Date -Format 'yyyy-MM-dd hh:mm:ss')] Collecting DNS Admins Memberships" -Verbose
    $DnsAdminsMemberships = Get-BTDnsAdminsMembership -Domains $Domains

    Write-Verbose "[$(Get-Date -Format 'yyyy-MM-dd hh:mm:ss')] Collecting DNS Update Proxy Memberships" -Verbose
    $DnsUpdateProxyMemberships = Get-BTDnsUpdateProxyMembership -Domains $Domains

    Write-Verbose "[$(Get-Date -Format 'yyyy-MM-dd hh:mm:ss')] Collecting Dynamic Update Service Accounts" -Verbose
    $DynamicUpdateServiceAccounts = Get-BTDynamicUpdateServiceAccount -Domains $Domains

    Write-Verbose "[$(Get-Date -Format 'yyyy-MM-dd hh:mm:ss')] Collecting Forwarder Configuration" -Verbose
    $ForwarderConfigurations = Get-BTForwarderConfiguration -Domains $Domains -Exclude $Exclude

    Write-Verbose "[$(Get-Date -Format 'yyyy-MM-dd hh:mm:ss')] Collecting Global Query Blocklists" -Verbose
    $GlobalQueryBlockLists = Get-BTGlobalQueryBlockList -Domains $Domains -Exclude $Exclude

    # Write-Verbose "[$(Get-Date -Format 'yyyy-MM-dd hh:mm:ss')] Collecting Name Protection Configuration Lists" -Verbose
    # $NameProtectionConfigurationLists = Get-BTNameProtectionConfiguration -Domains $Domains

    Write-Verbose "[$(Get-Date -Format 'yyyy-MM-dd hh:mm:ss')] Collecting Non ADI Zones" -Verbose
    $NonADIZones = Get-BTNonADIZone -Domains $Domains -Exclude $Exclude

    Write-Verbose "[$(Get-Date -Format 'yyyy-MM-dd hh:mm:ss')] Collecting Query Resolution Policies" -Verbose
    $QueryResolutionPolicys = Get-BTQueryResolutionPolicy -Domains $Domains -Exclude $Exclude

    # Write-Verbose "[$(Get-Date -format 'yyyy-MM-dd hh:mm:ss')] Collecting Security Descriptors" -Verbose
    # $SecurityDescriptors = Get-BTSecurityDescriptor -Domains $Domains

    Write-Verbose "[$(Get-Date -Format 'yyyy-MM-dd hh:mm:ss')] Collecting Socket Pool Sizes" -Verbose
    $SocketPoolSizes = Get-BTSocketPoolSize -Domains $Domains -Exclude $Exclude

    Write-Verbose "[$(Get-Date -Format 'yyyy-MM-dd hh:mm:ss')] Collecting Tombstoned Nodes" -Verbose
    $TombstonedNodes = Get-BTTombstonedNode -Domains $Domains -Exclude $Exclude

    Write-Verbose "[$(Get-Date -Format 'yyyy-MM-dd hh:mm:ss')] Collecting Wildcard Records" -Verbose
    $WildcardRecords = Get-BTWildcardRecord -Domains $Domains

    Write-Verbose "[$(Get-Date -Format 'yyyy-MM-dd hh:mm:ss')] Collecting WPAD Records" -Verbose
    $WPADRecords = Get-BTWPADRecord -Domains $Domains

    Write-Verbose "[$(Get-Date -Format 'yyyy-MM-dd hh:mm:ss')] Collecting Zone Scopes" -Verbose
    $ZoneScopes = Get-BTZoneScope -Domains $Domains -Exclude $Exclude

    Write-Verbose "[$(Get-Date -Format 'yyyy-MM-dd hh:mm:ss')] Collecting Zone Scope Containers" -Verbose
    $ZoneScopeContainers = Get-BTZoneScopeContainer -ADIZones $ADIZones

    Write-Host 'Finished collecting DNS data from the following domains:' -ForegroundColor Green
    Write-Host $Domains.split(' ')-ForegroundColor Yellow

    $CollectedData = [ordered]@{
        'ADIZones'                     = $ADIZones
        'ConditionalForwarders'        = $ConditionalForwarders
        'DanglingSPNs'                 = $DanglingSPNs
        'DnsAdminsMemberships'         = $DnsAdminsMemberships
        'DnsUpdateProxyMemberships'    = $DnsUpdateProxyMemberships
        'DynamicUpdateServiceAccounts' = $DynamicUpdateServiceAccounts
        'ForwarderConfigurations'      = $ForwarderConfigurations
        'GlobalQueryBlockLists'        = $GlobalQueryBlockLists
        # 'NameProtectionLists'         = $NameProtectionConfigurationLists
        'NonADIZones'                  = $NonADIZones
        'QueryResolutionPolicys'       = $QueryResolutionPolicys
        # 'SecurityDescriptors'          = $SecurityDescriptors
        'SocketPoolSizes'              = $SocketPoolSizes
        'TombstonedNodes'              = $TombstonedNodes
        'WildcardRecords'              = $WildcardRecords
        'WPADRecords'                  = $WPADRecords
        'ZoneScopes'                   = $ZoneScopes
        'ZoneScopeContainers'          = $ZoneScopeContainers
    }
    #endregion Get Data

    # Export the collected data to an individual file for each test
    if ($ExportCollectedData) {
        foreach ($item in $CollectedData.Keys) {
            if ($CollectedData.$Item -and $CollectedData.item.ToString().Length -gt 0) {
                Export-Results -Name "Collected $item" -Data $($CollectedData.$Item)
            }
        }
    }

    # Display All Collected Data
    $show = Read-Host 'Show all collected DNS data? [Y]/n'
    if (($show -eq 'y') -or ($show -eq '') -or ($null -eq $show) ) {
        if ($Demo) {
            Show-BTCollectedData -Demo @CollectedData
        } elseif ($ShowSecurityDescriptors) {
            Show-BTCollectedData -ShowSecurityDescriptors @CollectedData
        } elseif ($Demo -and $ShowSecurityDescriptors) {
            Show-BTCollectedData -ShowSecurityDescriptors -Demo @CollectedData
        } else {
            Show-BTCollectedData @CollectedData
        }
    }

    # Test Data
    if ($Demo) { Clear-Host }
    Write-Host 'Currently testing collected DNS data to identify possible issues...' -ForegroundColor Green

    Write-Verbose "[$(Get-Date -Format 'yyyy-MM-dd hh:mm:ss')] Testing ADI Legacy Zones"
    $TestedADILegacyZones = Test-BTADILegacyZone -ADIZones $ADIZones

    Write-Verbose "[$(Get-Date -Format 'yyyy-MM-dd hh:mm:ss')] Testing ADI Insecure Update Zones"
    $TestedADIInsecureUpdateZones = Test-BTADIInsecureUpdateZone -ADIZones $ADIZones

    Write-Verbose "[$(Get-Date -Format 'yyyy-MM-dd hh:mm:ss')] Testing Dynamic Update Service Accounts"
    $TestedDynamicUpdateServiceAccounts = Test-BTDynamicUpdateServiceAccount -DynamicUpdateServiceAccounts $DynamicUpdateServiceAccounts

    Write-Verbose "[$(Get-Date -Format 'yyyy-MM-dd hh:mm:ss')] Testing Forwarder Configurations"
    $TestedForwarderConfigurations = Test-BTForwarderConfiguration -ForwarderConfigurations $ForwarderConfigurations

    Write-Verbose "[$(Get-Date -Format 'yyyy-MM-dd hh:mm:ss')] Testing Global Query Block Lists"
    $TestedGlobalQueryBlockLists = Test-BTGlobalQueryBlockList -GlobalQueryBlockLists $GlobalQueryBlockLists

    # Write-Verbose "[$(Get-Date -Format 'yyyy-MM-dd hh:mm:ss')] Testing Security Descriptor ACE"
    # $TestedSecurityDescriptorACEs = Test-BTSecurityDescriptorACE -SecurityDescriptors $SecurityDescriptors -DynamicUpdateServiceAccounts $DynamicUpdateServiceAccounts -Domains $Domains

    # Write-Verbose "[$(Get-Date -Format 'yyyy-MM-dd hh:mm:ss')] Testing Security Descriptor Owner"
    # $TestedSecurityDescriptorOwners = Test-BTSecurityDescriptorOwner -SecurityDescriptors $SecurityDescriptors -DynamicUpdateServiceAccounts $DynamicUpdateServiceAccounts -Domains $Domains

    Write-Verbose "[$(Get-Date -Format 'yyyy-MM-dd hh:mm:ss')] Testing Socket Pool Sizes"
    $TestedSocketPoolSizes = Test-BTSocketPoolSize -SocketPoolSizes $SocketPoolSizes

    Write-Verbose "[$(Get-Date -Format 'yyyy-MM-dd hh:mm:ss')] Testing Wildcard Records"
    $TestedWildcardRecords = Test-BTWildcardRecord -WildcardRecords $WildcardRecords

    Write-Verbose "[$(Get-Date -Format 'yyyy-MM-dd hh:mm:ss')] Testing WPAD Records"
    $TestedWPADRecords = Test-BTWPADRecord -WPADRecords $WPADRecords

    Write-Verbose "[$(Get-Date -Format 'yyyy-MM-dd hh:mm:ss')] Testing Zone Scope Containers"
    $TestedZoneScopeContainers = Test-BTZoneScopeContainer -ZoneScopeContainers $ZoneScopeContainers

    Write-Host "Finished testing collected DNS data to identify possible issues.`n" -ForegroundColor Green

    $TestedData = [ordered]@{
        'ConditionalForwarders'              = $ConditionalForwarders
        'DanglingSPNs'                       = $DanglingSPNs
        'DnsAdminsMemberships'               = $DnsAdminsMemberships
        'DnsUpdateProxyMemberships'          = $DnsUpdateProxyMemberships
        'NonADIZones'                        = $NonADIZones
        'QueryResolutionPolicys'             = $QueryResolutionPolicys
        'TombstonedNodes'                    = $TombstonedNodes
        'ZoneScopes'                         = $ZoneScopes
        'TestedADILegacyZones'               = $TestedADILegacyZones
        'TestedADIInsecureUpdateZones'       = $TestedADIInsecureUpdateZones
        'TestedDynamicUpdateServiceAccounts' = $TestedDynamicUpdateServiceAccounts
        'TestedForwarderConfigurations'      = $TestedForwarderConfigurations
        'TestedGlobalQueryBlockLists'        = $TestedGlobalQueryBlockLists
        'TestedSecurityDescriptorACEs'       = $TestedSecurityDescriptorACEs
        'TestedSecurityDescriptorOwners'     = $TestedSecurityDescriptorOwners
        'TestedSocketPoolSizes'              = $TestedSocketPoolSizes
        'TestedWildcardRecords'              = $TestedWildcardRecords
        'TestedWPADRecords'                  = $TestedWPADRecords
        'TestedZoneScopeContainers'          = $TestedZoneScopeContainers
    }

    # Export the tested data to individual files for each test
    if ($ExportTestedData) {
        foreach ($item in $TestedData.Keys) {
            if ($TestedData.$Item -and $TestedData.item.ToString().Length -gt 0) {
                Export-Results -Name "Tested $item" -Data $TestedData.$Item
            }
        }
    }

    # Display All Tested Data
    $show = Read-Host 'Show possible DNS issues in the environment? [Y]/n'
    if (($show -eq 'y') -or ($show -eq '') -or ($null -eq $show) ) {
        if ($Demo) {
            Show-BTTestedData -Demo @TestedData
        } elseif ($ShowSecurityDescriptors) {
            Show-BTTestedData -ShowSecurityDescriptors @TestedData
        } elseif ($Demo -and $ShowSecurityDescriptors) {
            Show-BTTestedData -ShowSecurityDescriptors -Demo @TestedData
        } else {
            Show-BTTestedData @TestedData
        }
    }

    # Display Fixes
    $show = Read-Host 'Show fixes for identified issues? [Y]/n'
    if (($show -eq 'y') -or ($show -eq '') -or ($null -eq $show) ) {
        if ($Demo) {
            Show-BTFixes -Demo @TestedData
        } elseif ($ShowSecurityDescriptors) {
            Show-BTFixes -ShowSecurityDescriptors @TestedData
        } elseif ($Demo -and $ShowSecurityDescriptors) {
            Show-BTFixes -ShowSecurityDescriptors -Demo @TestedData
        } else {
            Show-BTFixes @TestedData
        }
    }

    # Return the TestedData
    Write-Host 'Tested Data: '
    return $TestedData
}
