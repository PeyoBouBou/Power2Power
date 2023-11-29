# Following modules are requi red to run suspension list scripts
Install-Module -Name Microsoft.PowerApps.Administration.PowerShell -Force
Install-Module -Name Microsoft.PowerApps.PowerShell -Allowclobber -Force

# Display the suspension list for a specific envi ronment in the console window
Get-AdminFlowAtRiskofsuspension -EnvironmentName cfdOS3S6-f25c-4d53-a36f-eeabd47a63a -Apiversion '2016-11-01'

# Add the suspension list for a specific envi ronment in the console window
Get-AdminFlowAtRiskofsuspension -EnvironmentName cfd05356-f25c-4dS3-a36f-eeabd47a63a2 -ApiVersion '2016-11-01' | Export-csv -Path suspensionlist.csv

# Get the suspension list for a tenant. It works with first SOO orgs in the tenant
$environments = Get-AdminPowerAppEnvironment
$allFlows = @()
foreach ($env in $environments) {
    write-Host "Getting flows at risk of suspension for environment $($env.DisplayName)..."
    $flows = Get-AdminFlowAtRiskOfSuspension -EnvironmentName $env.EnvironmentName
    write-Host "Found $($flows.Count) flows at risk of suspension."
    $allFlows += $flows
}

 ## get seperate file every org in the tenant
Add-PowerAppsAccount
$environments = Get-PowerAppEnvironment
ForEach($environment in $env){
    $flowlist = Get-AdminFlowAtRiskOfSuspension -EnvironmentName $environment.EnvironmentName -ApiVersion '2016-11-01' ##| Export-csv -Path $environment.DisplayName + '.csv'
    if ($flowlist.Length -gt 0)
    {
        $filename = $environment.DisplayName + '.csv'
        $flowlist | Export-csv -Path $filename -NoTypeInformation
    }

}
