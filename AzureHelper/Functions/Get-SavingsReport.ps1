
Function Get-AHSavingsReport {
    <#
.SYNOPSIS
    Retrieves a list of changes that can be made to a subscription to cut costs

.DESCRIPTION
    Get-AHSavingsReport is a function that compiles a list of changes for each subscription
    to cut costs utilizing other functions in the AzureHelper module.  

.PARAMETER AllSubscriptions
    Run this command against all subscriptions.

.PARAMETER Subscription
    Specifies the subscription to run against. The default is the current subscription.

.PARAMETER ReportPath
    Specifies the path the report should be output to

.PARAMETER UnusedNICs

.PARAMETER UnusedPIPs

.PARAMETER UnusedDisks

.EXAMPLE
    Get-NonCompliantResources -AllSubscriptions

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

        [switch]
        $HTML,

        [switch]
        $CSV,

        [Parameter(ValueFromPipeline = $true)]
        $Subscription,

        [string]
        $ReportPath = ".\"
    )
    begin {
        #validate ReportPath here
        If (!(Test-Path $ReportPath)) {
            Throw("Invalid Path")
        }
        Else {
            $ReportPath = (Convert-Path $ReportPath) + '\' 
        }
        $ArgumentList = @()
        $ArgumentList += $CSV
        $ArgumentList += $HTML
        $MyScriptBlock = {
            param($CSV, $HTML)
            $ReportName = (Get-AzContext).name.split('(')[0].replace(' ', '')
            
            $UnusedDisks = Get-UnusedDisks
            $UnusedNICs = Get-UnusedNICs
            $UnusedPIPs = Get-UnusedPIPs
            $DBAllocation = Get-DBAllocation
            $ExtraDiskGBPaidFor = Get-ExtraDiskGBPaidFor
            $AHNonHubWindowsServers = Get-AHNonHubWindowsServers
            
            If ($CSV) {
                $UnusedDisks  | Export-Csv $($ReportPath + $ReportName + '-Savings-UnusedDisks.csv') -NoTypeInformation
                $UnusedNICs   | Export-Csv $($ReportPath + $ReportName + '-Savings-UnusedNICs.csv') -NoTypeInformation
                $UnusedPIPs   | Export-Csv $($ReportPath + $ReportName + '-Savings-UnusedPIPs.csv') -NoTypeInformation
                $DBAllocation | Export-Csv $($ReportPath + $ReportName + '-Savings-DBAllocation.csv') -NoTypeInformation
                $ExtraDiskGBPaidFor | Export-Csv $($ReportPath + $ReportName + '-Savings-ExtraDiskGBPaidFor.csv') -NoTypeInformation
                $AHNonHubWindowsServers | Export-Csv  $($ReportPath + $ReportName + '-Savings-NonAHUBWindowsServers.csv') -NoTypeInformation
            }
            If ($HTML) {
                "<h1>" + (Get-Date) + "</h1>" | Out-File $($ReportPath + $ReportName + '-Savings.html') -Append
                "<h1>Unused Disks</h1>" | Out-File $($ReportPath + $ReportName + '-Savings.html') -Append
                $UnusedDisks  | ConvertTo-Html | Out-File $($ReportPath + $ReportName + '-Savings.html') -Append
                "<h1>Unused NICs</h1>" | Out-File $($ReportPath + $ReportName + '-Savings.html') -Append
                $UnusedNICs   | ConvertTo-Html | Out-File $($ReportPath + $ReportName + '-Savings.html') -Append
                "<h1>Unused PIPs</h1>" | Out-File $($ReportPath + $ReportName + '-Savings.html') -Append
                $UnusedPIPs   | ConvertTo-Html | Out-File $($ReportPath + $ReportName + '-Savings.html') -Append
                "<h1>DB Allocation</h1>" | Out-File $($ReportPath + $ReportName + '-Savings.html') -Append
                $DBAllocation | ConvertTo-Html | Out-File $($ReportPath + $ReportName + '-Savings.html') -Append
                "<h1>Extra Disk GB Paid For</h1>" | Out-File $($ReportPath + $ReportName + '-Savings.html') -Append
                $ExtraDiskGBPaidFor | ConvertTo-Html | Out-File $($ReportPath + $ReportName + '-Savings.html') -Append
                "<h1>Non hybrid benefit Windows Servers</h1>" | Out-File $($ReportPath + $ReportName + '-Savings.html') -Append
                $AHNonHubWindowsServers | ConvertTo-Html | Out-File $($ReportPath + $ReportName + '-Savings.html') -Append
            }
 
        }
    }
    process {
        if ($Subscription) { $Subscription | Invoke-AzureCommand -ScriptBlock $MyScriptBlock -ArgumentList $ArgumentList }
        else { Invoke-AzureCommand -ScriptBlock $MyScriptBlock -AllSubscriptions:$AllSubscriptions -ArgumentList $ArgumentList }
    }

}
