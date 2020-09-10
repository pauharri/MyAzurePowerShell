
Function Get-SecurityReport {
    <#
.SYNOPSIS
    Retrieves a list of changes that can be made to a subscription to be more secure.

.DESCRIPTION
    Get-SavingsReport is a function that compiles a list of changes for each subscription
    to cut costs utilizing other functions in the AzureHelper module.  

.PARAMETER AllSubscriptions
    Run this command against all subscriptions.

.PARAMETER Subscription
    Specifies the subscription to run against. The default is the current subscription.

.PARAMETER ReportPath
    Specifies the path the report should be output to

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
    
        [Parameter(ValueFromPipeline = $true)]
        $Subscription,

        [parameter]
        $ReportPath
    )
    begin {
        
    }
    process{

    }

}