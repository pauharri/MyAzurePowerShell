function Get-UnusedDisks {
    <#
.SYNOPSIS
    Gets a list of unused NICs in the environment.

.DESCRIPTION
    Get-UnusedDisks is a function that returns a list of Diskss that are not attached
    in the environment.  This can occur when VMs are deleted but not the Disks attached
    to the VM.  

.PARAMETER AllSubscriptions
    Run this command against all subscriptions.

.PARAMETER Subscription
    Specifies the subscription to run against. The default is the current subscription.

.EXAMPLE
    Get-UnusedDisks -AllSubscriptions

.EXAMPLE
    Get-UnusedDisks -AllSubscriptions | Export-Csv UnusedDisks.csv -NoTypeInformation

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
