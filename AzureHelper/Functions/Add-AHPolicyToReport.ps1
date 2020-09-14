Function Add-AHPolicyToReport {
    <#
.SYNOPSIS
    Adds an Azure policy to the list of policies to be analyzed.
.DESCRIPTION
    Add-AHPolicyToReport adds an Azure Policy to the list of policies
    to be analyzed by other AzureHelper cmdlets.
.PARAMETER PolicyDefinitionID
    Define the policy to be added by the PolicyDefinitionID
.PARAMETER GUI
    Use the GUI switch to use the GUI to select the PolicyDefinitions to add
.EXAMPLE
    Add-AHPolicyToReport -PolicyDefinitionID 
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
    .LINK
    Get-AHSecurityReport
    Add-AHPolicyToReport
    Get-AHPolicyToReport
    Remove-AHPolicyToReport
    Get-AHComplianceReport
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [string[]]
        $PolicyDefinitionID,
        
        [switch]
        $GUI
    )
    If ($GUI) {
        (Get-AzPolicyDefinition | Select-Object * -ExpandProperty Properties | Out-GridView -PassThru -Title "Select the policies to add to your report").PolicyDefinitionId | Add-AHPolicyToReport
    }

    ForEach ($ID in $PolicyDefinitionID) {
        If ($Null -eq $PolicyDefinitionID -or (Get-AzPolicyDefinition -Id $PolicyDefinitionID) -is [array]) { 
            #If a PolicyDefinitionID is passed at the CLI and is malformed then this will return an array and re-prompt the user for a correct value
            throw { "Invalid PolicyDefinitionID" }
        }
        Elseif ($Script:PolicyDefinitionIDs -contains $PolicyDefinitionID) {
            Throw { "The PolicyDefinitionID $PolicyDefinitionID is already in the list." }
        }
        Else {
            $Script:PolicyDefinitionIDs += $PolicyDefinitionID
        }
    }
}
