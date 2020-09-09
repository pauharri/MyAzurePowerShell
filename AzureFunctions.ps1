function Invoke-AzureCommand {
    <#
.SYNOPSIS
    Runs a script block against every subscription or a different subscription than
    the current context.

.DESCRIPTION
    Invoke-AzureCommand runs a script block against a different context or every 
    subscription.  

.PARAMETER AllSubscriptions
    Run this command against all subscriptions.

.PARAMETER Subscription
    Specifies the subscription to run against. The default is the current subscription.

.EXAMPLE
     Invoke-AllSubs -ScriptBlock ([scriptblock]::Create('write-host "hello world from $((get-azcontext).name)"'))

.EXAMPLE
     $DiskScriptBlock = {Get-AzDisk | Where{$_.DiskSizeGB -gt 512}}
    Invoke-AzureCommand -AllSubscriptions -ScriptBlock $DiskScriptBlock | FT ResourceGroupName, Name, DiskSizeGB

    This example finds every disk larger than 512 GB in every subscription

.INPUTS
    ScriptBlock

.OUTPUTS
    Array

.NOTES
    Author:  Paul Harrison
#>
    [CmdletBinding()]
    param (
        [ScriptBlock]
        $ScriptBlock,
    
        [Parameter(ValueFromPipeline = $true)]
        $Subscription,
    
        [switch]
        $AllSubscriptions
    )

    process {
        if (-not $AllSubscriptions -and -not $Subscription) {
            return $ScriptBlock.Invoke()
        }
    
        $currentSub = Get-AzContext
    
        if ($Subscription) { $subs = $Subscription }
        else { $subs = Get-AzSubscription }
    
        $subCount = 0
        foreach ($sub in $subs) {
            Set-AzContext $sub | Out-Null
            Write-Progress -Activity "Checking each subscription" -Status (Get-AzContext).Subscription.Name -PercentComplete (100 * $subCount / $($subs.count))
            $ScriptBlock.Invoke()
            $subCount++
        }
        $null = Set-AzContext $currentSub
    }
}

function Get-UnusedPIPs {
    <#
.SYNOPSIS
    Gets a list of unused Public IPs in the environment.

.DESCRIPTION
    Get-UnusedPIPs is a function that returns a list of Public IPs that do not have a
    IPConfiguration.ID defined in the environment.  

.PARAMETER AllSubscriptions
    Run this command against all subscriptions.

.PARAMETER Subscription
    Specifies the subscription to run against. The default is the current subscription.

.EXAMPLE
    Get-UnusedPIPs -AllSubscriptions

.EXAMPLE
    Get-UnusedPIPs -AllSubscriptions | Export-Csv UnusedPIPs.csv -NoTypeInformation

.INPUTS
    String

.OUTPUTS
    Selected.Microsoft.Azure.Commands.Network.Models.PSPublicIpAddress

.NOTES
    Author:  Paul Harrison
#>
    [CmdletBinding()]
    param (
        [Switch]
        $AllSubscriptions,
    
        [Parameter(ValueFromPipeline = $true)]
        $Subscription
    )
    begin {
        $MyScriptBlock = {
            Get-AzPublicIpAddress | Where-Object {
                $null -eq $_.IpConfiguration.Id
            } | Select-Object @{ N = "Subscription"; E = { (Get-AzContext).Subscription.Name } }, ResourceGroupName, Location, Name, Id, PublicIpAllocationMethod, PublicIpAddressVersion, IpAddress
        }
    }
    process {
        if ($Subscription) { $Subscription | Invoke-AzureCommand -ScriptBlock $MyScriptBlock }
        else { Invoke-AzureCommand -ScriptBlock $MyScriptBlock -AllSubscriptions:$AllSubscriptions }
    }
}


function Get-UnusedNICs {
    <#
.SYNOPSIS
    Gets a list of unused NICs in the environment.

.DESCRIPTION
    Get-UnusedNICs is a function that returns a list of NICs that are not attached
    in the environment.  This can occur when VMs are deleted but not the NICs attached
    to the VM.  

.PARAMETER AllSubscriptions
    Run this command against all subscriptions.

.PARAMETER Subscription
    Specifies the subscription to run against. The default is the current subscription.

.EXAMPLE
    Get-UnusedNICs -AllSubscriptions

.EXAMPLE
    Get-UnusedNICs -AllSubscriptions | Export-Csv UnusedNICs.csv -NoTypeInformation

.INPUTS
    String

.OUTPUTS
    Selected.Microsoft.Azure.Commands.Compute.Automation.Models.PSDiskList

.NOTES
    Author:  Paul Harrison
#>
    [CmdletBinding()]
    param (
        [Switch]
        $AllSubscriptions,
    
        [Parameter(ValueFromPipeline = $true)]
        $Subscription
    )
    begin {
        $MyScriptBlock = {
            Get-AzDisk | Where-Object {
                $null -eq $_.ManagedBy
            } | Select-Object @{N = "Subscription"; E = { (Get-AzContext).Subscription.Name } }, ResourceGroupName, ManagedBy, DiskState, OsType, Location, DiskSizeGB, Id, Name
        }
    }
    process {
        if ($Subscription) { $Subscription | Invoke-AzureCommand -ScriptBlock $MyScriptBlock }
        else { Invoke-AzureCommand -ScriptBlock $MyScriptBlock -AllSubscriptions:$AllSubscriptions }
    }
}


function Get-DBAllocation {
    <#
.SYNOPSIS
    Gets every Azure DB and returns key information to help make choices about
    reducing the cost of your SQL DBs.

.DESCRIPTION
    Get-DBAllocation is a function that returns a list of Azure SQL DBs and
    the maximum cpu_percent over the past 14 days,how the licenses are being 
    paid for, and how many CPUs are allocated.  

.PARAMETER AllSubscriptions
    Run this command against all subscriptions.

.PARAMETER Subscription
    Specifies the subscription to run against. The default is the current subscription.

.EXAMPLE
    Get-DBAllocation -AllSubscriptions

.EXAMPLE
    Get-DBAllocation -AllSubscriptions | Export-Csv DBAllocation.csv -NoTypeInformation

.INPUTS
    String

.OUTPUTS
    Selected.Microsoft.Azure.Commands.Sql.Database.Model.AzureSqlDatabaseModel

.NOTES
    Author:  Paul Harrison
#>
    [CmdletBinding()]
    param (
        [Switch]
        $AllSubscriptions,
    
        [Parameter(ValueFromPipeline = $true)]
        $Subscription
    )
    begin {
        $MyScriptBlock = {
            Get-AzSqlServer | Get-AzSqlDatabase | `
                Select-Object @{N = "Subscription"; E = { (Get-AzContext).Subscription.Name } }, ResourceGroupName, ServerName, DatabaseName, DatabaseId, CurrentServiceObjectiveName, Capacity, `
                Family, SkuName, LicenseType, Location, ZoneRedundant, `
            @{N = "MaxCPU"; E = { ((Get-AzMetric -WarningAction 0 -ResourceId $_.ResourceId -MetricName cpu_percent -TimeGrain 01:00:00 -StartTime ((Get-Date).AddDays(-14)) -EndTime (Get-Date) -AggregationType Maximum | Select-Object -ExpandProperty Data).maximum | Measure-Object -Maximum).Maximum } }
        }
    }
    process {
        if ($Subscription) { $Subscription | Invoke-AzureCommand -ScriptBlock $MyScriptBlock }
        else { Invoke-AzureCommand -ScriptBlock $MyScriptBlock -AllSubscriptions:$AllSubscriptions }
    }
}

Function New-Route {
    <#
.SYNOPSIS
    Creates a new UDR to allow traffic to an Azure Service

.DESCRIPTION
    New-Route provides a GUI and automation to add all the routes needed
    for a UDR for access to a particular service endpoint.  

.PARAMETER MaxRoutesPerRouteTable
    The current limitation for routes per route table is 400.  If that limit 
    is changed then override that limit by using this parameter.

.EXAMPLE
     New-Route

.EXAMPLE
     New-Route -MaxRoutePerRouteTable 500

.INPUTS
    Int32

.OUTPUTS
    Microsoft.Azure.Commands.Network.Models.PSRoute

.NOTES
    Author:  Paul Harrison
#>
    param(
        $MaxRoutesPerRouteTable = 400
    )

    $location = (Get-AzLocation | Out-GridView -PassThru -Title "Select the location").location
    $serviceTagRaw = (Get-AzNetworkServiceTag -Location $location).Values | Out-GridView -PassThru -Title "Select the Network Service Tag"
    $RouteTable = Get-AzRouteTable | Out-GridView -PassThru -Title "Select the Route Table to modify"
    If ((Get-AzRouteTable -ResourceGroupName $($RouteTable.ResourceGroupName) -Name $($RouteTable.Name)).routes.count + $($serviceTagRaw.properties.addressprefixes).count -gt $MaxRoutesPerRouteTable ) {
        Write-Error "This action would add more than $MaxRoutesPerRouteTable to the table.  No routes have been added."
    }
    Else {
        ForEach ($AddressPrefix in $($serviceTagRaw.properties.addressprefixes)) {
            $RouteName = $($serviceTagRaw.name) + $($AddressPrefix.split('/')[0])
            (Get-AzRouteTable -ResourceGroupName $($RouteTable.ResourceGroupName) -Name $($RouteTable.Name) | Add-AzRouteConfig -Name $RouteName -AddressPrefix $AddressPrefix -NextHopType Internet | Set-AzRouteTable).Routes | Where-Object { $_.Name -eq $RouteName } #| FT Name, ProvisioningState, AddressPrefix, NextHopType, NextHotIPAddress
        }
    }
}


function Get-ExtraDiskGBPaidFor {
    <#
.SYNOPSIS
    Gets every disk and returns how much space is paid for but not allocated.

.DESCRIPTION
    Get-ExtraDiskGBPaidFor is a function that returns a list of Azure Disks and
    the size in GB that is being paid for but is not currently allocated.  

.PARAMETER AllSubscriptions
    Run this command against all subscriptions.

.PARAMETER Subscription
    Specifies the subscription to run against. The default is the current subscription.

.EXAMPLE
     Get-ExtraDiskGBPaidFor -AllSubscriptions

.EXAMPLE
     Get-ExtraDiskGBPaidFor -AllSubscriptions | Export-Csv ExtraDiskGBPaidFor.csv -NoTypeInformation

.INPUTS
    String

.OUTPUTS
    Selected.Microsoft.Azure.Commands.Compute.Automation.Models.PSDiskList

.NOTES
    Author:  Paul Harrison
#>
    [CmdletBinding()]
    param (
        [Switch]
        $AllSubscriptions,
    
        [Parameter(ValueFromPipeline = $true)]
        $Subscription
    )

    begin {
        Function Get-ExtraGBPaidForHelper {
            param(
                $disk
            )
            $PList = @(4, 8, 16, 32, 64, 128, 256, 512, 1024, 2048, 4096, 8192, 16384, 32767) #premium ssd
            $EList = @(4, 8, 16, 32, 64, 128, 256, 512, 1024, 2048, 4096, 8192, 16384, 32767) #standard ssd
            $SList = @(32, 64, 128, 256, 512, 1024, 2048, 4096, 8192, 16384, 32767) #standard hdd
        
            If ($($disk.sku.Name) -like "*UltraSSD*") {
                0
            }
            ElseIf ($($disk.sku.Name) -like "*Premium*") {
                $allowedDiskSizes = $PList
            }
            Elseif ($($disk.sku.Name) -like "*StandardSSD*") {
                $allowedDiskSizes = $EList
            }
            Elseif ($($disk.sku.Name) -like "*Standard*") {
                $allowedDiskSizes = $SList
            }
        
            If ($allowedDiskSizes -contains $($disk.diskSizeGB)) {
                0
            }
            Elseif ($($disk.diskSizeGB) -gt $($allowedDiskSizes[$allowedDiskSizes.Count - 1])) {
                Write-Error "Disk size too big"
            }
            Else {
                If (($($disk.diskSizeGB) -lt $allowedDiskSizes[0])) {
                    $allowedDiskSizes[0] - $($disk.diskSizeGB)
                }
                Else {
                    For ($i = 0; $i -lt $($allowedDiskSizes.Count - 1); $i++) {
                        If (($($disk.diskSizeGB) -gt $allowedDiskSizes[$i]) -and ($($disk.diskSizeGB) -lt $allowedDiskSizes[($i + 1)])) {
                            $allowedDiskSizes[$i + 1] - $($disk.diskSizeGB)
                        }
                    }
                }
            }
        }
        $MyScriptBlock = {
            Get-AzDisk | Select-Object @{ N = "Subscription"; E = { (Get-AzContext).Subscription.Name } }, ResourceGroupName, Name, Id, OsType, DiskSizeGB, @{N = "ExtraGBPaidFor"; E = { Get-ExtraGBPaidForHelper -disk $_ } }
        }        
    }
    process {
        if ($Subscription) { $Subscription | Invoke-AzureCommand -ScriptBlock $MyScriptBlock }
        else { Invoke-AzureCommand -ScriptBlock $MyScriptBlock -AllSubscriptions:$AllSubscriptions }
    }
}


Function Get-NonCompliantResources {
    <#
.SYNOPSIS
    Prompts the user to select an Azure Policy then returns a list of resources 
    that are not comnpliant with the policy.

.DESCRIPTION
    Get-NonCompliantResources is a function that returns a list of resources that 
    are not compliaint with the policy that the user selects.  

.PARAMETER AllSubscriptions
    Run this command against all subscriptions.

.PARAMETER Subscription
    Specifies the subscription to run against. The default is the current subscription.

.PARAMETER PolicyDefinitionId
    Specifies the PolicyDefinitionId of the policy to check for compliance against.

.EXAMPLE
    Get-NonCompliantResources -AllSubscriptions

.EXAMPLE
    Get-NonCompliantResources -AllSubscriptions | Export-Csv NonCompliantResources-Policy1.csv -NoTypeInformation

.EXAMPLE
    Get-NonCompliantResources -AllSubscriptions -PolicyDefinitionID '/providers/Microsoft.Authorization/policyDefinitions/34c877ad-507e-4c82-993e-3452a6e0ad3c' | Export-Csv .\StorageAccountsShouldRestrictNetworkAccess2.csv -NoTypeInformation

.INPUTS
    String

.OUTPUTS
    Selected.Microsoft.Azure.Commands.ResourceManager.Cmdlets.SdkModels.PSResource

.NOTES
    Author:  Paul Harrison
#>
    [CmdletBinding()]
    param (
        [Switch]
        $AllSubscriptions,
    
        [Parameter]
        $Subscription,

        [parameter(ValueFromPipeline = $true)]
        $PolicyDefinitionID
    )
    begin {
        If ($Null -eq $PolicyDefinitionID) {
            $PolicyDefinitionID = (Get-AzPolicyDefinition | Select-Object * -ExpandProperty Properties | Out-GridView -PassThru -Title "Select the Policy to check for compliance.").ResourceId
        }
        ElseIf ((Get-AzPolicyDefinition -Id $PolicyDefinitionID) -is [array]) { #If a PolicyDefinitionID is passed at the CLI and is malformed then this will return an array and re-prompt the user for a correct value
            $PolicyDefinitionID = @()
        }
        While ($PolicyDefinitionID -is [array]) {
            Write-Warning "Only one Policy may be selected at a time."
            $PolicyDefinitionID = (Get-AzPolicyDefinition | Select-Object * -ExpandProperty Properties | Out-GridView -PassThru  -Title "Select the Policy to check for compliance.").ResourceId
        }
        $MyScriptBlock = {
            Get-AzPolicyState -Filter "PolicyDefinitionId eq '$PolicyDefinitionID' AND ComplianceState eq 'NonCompliant'" |  Get-AzResource | Select-Object @{N = "Subscription"; E = { (Get-AzContext).Subscription.Name } }, ResourceGroupName, ResourceName, ResourceId
        }
    }
    process {
        if ($Subscription) { $Subscription | Invoke-AzureCommand -ScriptBlock $MyScriptBlock }
        else { Invoke-AzureCommand -ScriptBlock $MyScriptBlock -AllSubscriptions:$AllSubscriptions }
    }
}
