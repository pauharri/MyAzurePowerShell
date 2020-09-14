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