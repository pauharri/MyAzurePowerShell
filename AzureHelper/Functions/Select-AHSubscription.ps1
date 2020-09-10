Function Select-AHSubscription {
    $sub = $Null
    While ($Null -eq $sub -or $sub -is [array]) {
        $sub = (Get-AzSubscription | Select-Object Name, Id | Out-GridView -PassThru -Title "Select the subscription to use")
    }
    try { Set-AzContext $($sub.id) }
    catch { throw }
}