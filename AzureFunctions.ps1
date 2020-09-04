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
