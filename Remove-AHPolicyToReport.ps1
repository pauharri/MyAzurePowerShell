Function Remove-AHPolicyToReport {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [string]
        $PolicyDefinitionID
    )
    If ($Null -eq $PolicyDefinitionID<# -or (Get-AzPolicyDefinition -Id $PolicyDefinitionID) -is [array]#>) { 
        #If a PolicyDefinitionID is passed at the CLI and is malformed then this will return an array and re-prompt the user for a correct value
        throw { "Invalid PolicyDefinitionID" }
    }
    Elseif ($Script:PolicyDefinitionIDs -notcontains $PolicyDefinitionID) {
        Throw { "The PolicyDefinitionID $PolicyDefinitionID is not in the list." }
    }
    Else {
        $Script:PolicyDefinitionIDs = $Script:PolicyDefinitionIDs -ne $PolicyDefinitionID
    }
}