
Function Get-AHSecurityReport {
    <#
.SYNOPSIS
    Retrieves a list of changes that can be made to a subscription to be more secure.

.DESCRIPTION
    Get-AHSecurityReport is a function that compiles a list of changes for each subscription
    to increase security utilizing other functions in the AzureHelper module. The list of items
    that is checked is defined in $Script:PolicyDefinitionIDs and is accessed through 
    commands found in the LINK section 

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
    CSV Files

.NOTES
    Author:  Paul Harrison

.LINK
        Add-AHPolicyToReport
        Get-AHPolicyToReport
        Remove-AHPolicyToReport
        Get-AHComplianceReport
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
