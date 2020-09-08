function Invoke-AzureCommand {
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


function Get-UnusedNICs {
    [CmdletBinding()]
    param (
        [Switch]
        $AllSubscriptions,
    
        [Parameter(ValueFromPipeline = $true)]
        $Subscription
    )
    begin {
        $MyScriptBlock = {
            Get-AzDisk | Where-Object{
                $null -eq $_.ManagedBy
            } | Select-Object @{N="Subscription";E={(Get-AzContext).Subscription.Name}}, ResourceGroupName, ManagedBy, DiskState, OsType, Location, DiskSizeGB, Id, Name
        }
    }
    process {
        if ($Subscription) { $Subscription | Invoke-AzureCommand -ScriptBlock $MyScriptBlock }
        else { Invoke-AzureCommand -ScriptBlock $MyScriptBlock -AllSubscriptions:$AllSubscriptions }
    }
}


function Get-DBAllocation {
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
            Select-Object @{N="Subscription";E={(Get-AzContext).Subscription.Name}}, ResourceGroupName, ServerName, DatabaseName, DatabaseId, CurrentServiceObjectiveName, Capacity, `
            Family, SkuName, LicenseType, Location, ZoneRedundant, `
            @{N="MaxCPU";E={((Get-AzMetric -WarningAction 0 -ResourceId $_.ResourceId -MetricName cpu_percent -TimeGrain 01:00:00 -StartTime ((Get-Date).AddDays(-14)) -EndTime (Get-Date) -AggregationType Maximum | select -ExpandProperty Data).maximum | measure -Maximum).Maximum}}
        }
    }
    process {
        if ($Subscription) { $Subscription | Invoke-AzureCommand -ScriptBlock $MyScriptBlock }
        else { Invoke-AzureCommand -ScriptBlock $MyScriptBlock -AllSubscriptions:$AllSubscriptions }
    }
}

Function New-Route {
    param(
        $MaxRoutesPerRouteTable = 400
    )

    $location = (Get-AzLocation | ogv -PassThru -Title "Select the location").location
    $serviceTagRaw = (Get-AzNetworkServiceTag -Location $location).Values | ogv -PassThru -Title "Select the Network Service Tag"
    $RouteTable = Get-AzRouteTable | ogv -PassThru -Title "Select the Route Table to modify"
    If ((Get-AzRouteTable -ResourceGroupName $($RouteTable.ResourceGroupName) -Name $($RouteTable.Name)).routes.count + $($serviceTagRaw.properties.addressprefixes).count -gt $MaxRoutesPerRouteTable ) {
        Write-Error "This action would add more than $MaxRoutesPerRouteTable to the table.  No routes have been added."
    }
    Else {
        ForEach ($AddressPrefix in $($serviceTagRaw.properties.addressprefixes)) {
            $RouteName = $($serviceTagRaw.name) + $($AddressPrefix.split('/')[0])
            (Get-AzRouteTable -ResourceGroupName $($RouteTable.ResourceGroupName) -Name $($RouteTable.Name) | Add-AzRouteConfig -Name $RouteName -AddressPrefix $AddressPrefix -NextHopType Internet | Set-AzRouteTable).Routes | Where { $_.Name -eq $RouteName } #| FT Name, ProvisioningState, AddressPrefix, NextHopType, NextHotIPAddress
        }
    }
}


function Get-ExtraDiskGBPaidFor {
    [CmdletBinding()]
    param (
        [Switch]
        $AllSubscriptions,
    
        [Parameter(ValueFromPipeline = $true)]
        $Subscription
    )

    begin {
        Function Get-ExtraGBPaidForHelper{
            param(
                $disk
            )
            $PList = @(4,8,16,32,64,128,256,512,1024,2048,4096,8192,16384,32767) #premium ssd
            $EList = @(4,8,16,32,64,128,256,512,1024,2048,4096,8192,16384,32767) #standard ssd
            $SList = @(32,64,128,256,512,1024,2048,4096,8192,16384,32767) #standard hdd
        
            If($($disk.sku.Name) -like "*UltraSSD*"){
                0
            }
            ElseIf($($disk.sku.Name) -like "*Premium*"){
                $allowedDiskSizes = $PList
            }Elseif($($disk.sku.Name) -like "*StandardSSD*"){
                $allowedDiskSizes = $EList
            }Elseif($($disk.sku.Name) -like "*Standard*"){
                $allowedDiskSizes = $SList
            }
        
            If($allowedDiskSizes -contains $($disk.diskSizeGB)){
                0
            }
            Elseif($($disk.diskSizeGB) -gt $($allowedDiskSizes[$allowedDiskSizes.Count - 1])){
                Write-Error "Disk size too big"
            }
            Else{
                If(($($disk.diskSizeGB) -lt $allowedDiskSizes[0])){
                    $allowedDiskSizes[0] - $($disk.diskSizeGB)
                }Else{
                    For($i = 0;$i -lt $($allowedDiskSizes.Count -1);$i++){
                        If(($($disk.diskSizeGB) -gt $allowedDiskSizes[$i]) -and ($($disk.diskSizeGB) -lt $allowedDiskSizes[($i+1)])){
                            $allowedDiskSizes[$i+1]-$($disk.diskSizeGB)
                        }
                    }
                }
            }
        }
        $MyScriptBlock = {
            Get-AzDisk | select @{ N = "Subscription"; E = { (Get-AzContext).Subscription.Name } },ResourceGroupName, Name, Id, OsType, DiskSizeGB, @{N="ExtraGBPaidFor";E={Get-ExtraGBPaidForHelper -disk $_}}
        }        
    }
    process {
        if ($Subscription) { $Subscription | Invoke-AzureCommand -ScriptBlock $MyScriptBlock }
        else { Invoke-AzureCommand -ScriptBlock $MyScriptBlock -AllSubscriptions:$AllSubscriptions }
    }
}



