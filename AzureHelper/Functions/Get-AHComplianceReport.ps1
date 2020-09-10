Function Get-AHComplianceReport {
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

    [Parameter(ValueFromPipeline = $true)]
    $Subscription,

    [string]
    $ReportPath = ".\"
)
begin {
    #Validate there are PolicyIDs defined to run against
    If ($Null -eq $Script:PolicyDefinitionIDs) {
        throw { "No PolicyDefinitionIDs defined.  Use Add-AHPolicyToReport to add additional policies." }
    }
    #validate ReportPath here
    If (!(Test-Path $ReportPath)) {
        Throw("Invalid Path")
    }
    Else {
        $ReportPath = (Convert-Path $ReportPath) + '\' 
    }

    $MyScriptBlock = {
        ForEach ($PolicyId in $Script:PolicyDefinitionIDs) {
            $PolicyName = (Get-AzPolicyDefinition -Id $PolicyId).Properties.Displayname.replace(' ', '')
            If ($PolicyName.length -gt 35) {
                $PolicyName = $PolicyName.substring(0, 35)
            }
            $ReportName = $ReportPath + (Get-AzContext).name.split('(')[0].replace(' ', '') + '-Security-' + $PolicyName + '.csv'

            Get-NonCompliantResources -PolicyDefinitionID $PolicyId | Export-Csv $ReportName -NoTypeInformation
        }
    }
}
process {
    if ($Subscription) { $Subscription | Invoke-AzureCommand -ScriptBlock $MyScriptBlock }
    else { Invoke-AzureCommand -ScriptBlock $MyScriptBlock -AllSubscriptions:$AllSubscriptions }
}

}