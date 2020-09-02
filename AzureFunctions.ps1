
#Invoke a script block against all subscriptions
Function Invoke-AllSubs{
    param(
        [ScriptBlock]$ScriptBlock
    )

   $currentSub = Get-AzContext
    $myOutput = @()
    $subCount = 0
    $subs = Get-AzSubscription
    foreach ($sub in (Get-AzSubscription)) {
        Set-AzContext $sub | Out-Null
        Write-Progress -Activity "Checking each subscription" -Status (Get-AzContext).Subscription.Name -PercentComplete (100*$subCount/$($subs.count))
        $myOutput += $ScriptBlock.Invoke()
        $subCount++
    }
    Set-AzContext $currentSub | Out-Null
    return $myOutput
}


Function Get-UnusedPIPs{
    param(
        [Switch]$AllSubscriptions
    )
    $MyScriptBlock = [scriptblock]::Create('Get-AzPublicIpAddress | Where{$_.IpConfiguration.Id -eq $null} | select @{N="Subscription";E={(Get-AzContext).Subscription.Name}}, ResourceGroupName, Location, Name, Id, PublicIpAllocationMethod, PublicIpAddressVersion, IpAddress')
    If($AllSubscriptions){
        return Invoke-AllSubs -ScriptBlock $MyScriptBlock
    }Else{
        return $MyScriptBlock.Invoke()
    }
}

Function Get-UnusedNICs{
    param(
        [Switch]$AllSubscriptions
    )
    $MyScriptBlock = [scriptblock]::Create('Get-AzNetworkInterface | Where{$_.VirtualMachine -eq $null} | select @{N="Subscription";E={(Get-AzContext).Subscription.Name}}, ResourceGroupName, Location, VirtualMachine, Name, Id')
    If($AllSubscriptions){
        return Invoke-AllSubs -ScriptBlock $MyScriptBlock
    }Else{
        return $MyScriptBlock.Invoke()
    }
}


Function Get-UnusedDisks{
    param(
        [Switch]$AllSubscriptions
    )
    $MyScriptBlock = [scriptblock]::Create('Get-AzDisk | Where{$_.ManagedBy -eq $null} | select @{N="Subscription";E={(Get-AzContext).Subscription.Name}}, ResourceGroupName, ManagedBy, DiskState, OsType, Location, DiskSizeGB, Id, Name')
    If($AllSubscriptions){
        return Invoke-AllSubs -ScriptBlock $MyScriptBlock
    }Else{
        return $MyScriptBlock.Invoke()
    }
}


Function Get-DBAllocations{
    param(
        [Switch]$AllSubscriptions
    )
    $MyScriptBlock = [scriptblock]::Create('Get-AzSqlServer | Get-AzSqlDatabase | select @{N="Subscription";E={(Get-AzContext).Subscription.Name}}, ResourceGroupName, ServerName, DatabaseName, DatabaseId, CurrentServiceObjectiveName, Capacity, Family, SkuName, LicenseType, Location, ZoneRedundant, @{N="MaxCPU";E={((Get-AzMetric -WarningAction 0 -ResourceId $_.ResourceId -MetricName cpu_percent -TimeGrain 01:00:00 -StartTime ((Get-Date).AddDays(-14)) -EndTime (Get-Date) -AggregationType Maximum | select -ExpandProperty Data).maximum | measure -Maximum).Maximum}}')
    If($AllSubscriptions){
        return Invoke-AllSubs -ScriptBlock $MyScriptBlock
    }Else{
        return $MyScriptBlock.Invoke()
    }
}
