[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

#####################################################################################################
## FUNCTIONS
#####################################################################################################



#####################################################################################################
## MAIN
#####################################################################################################
Write-Host "START"


Import-Module PowerDataOps

# Script parameters : must be 'your' values
$mySolutionUniqueName = "MyFantasticSolution";
$url = "https://contoso.crm12.dynamics.com";
$clientId = "c6511040-5c20-4649-854e-dd78edfea759";
$clientSecret = "ds515sqd15d1q";

# Initialize connection
$connectionString = "AuthType=ClientSecret;Url=$url;ClientId=$clientId;ClientSecret=$clientSecret;"
$xrmClient = New-XrmClient -ConnectionString $connectionString;

# Retrieve solution record
$solution = Get-XrmRecord -LogicalName "solution" -AttributeName uniquename -Value $mySolutionUniqueName -Columns "*";

# Increase version
$actualVersion = [version] $solution.version;
$newVersion = "{0}.{1}.{2}.{3}" -f $actualVersion.Major, $actualVersion.Minor, $actualVersion.Build, $($actualVersion.Revision + 1)

# Update solution record with new version
$solutionUpdate = $solution.Record | Set-XrmAttributeValue -Name "version" -Value $newVersion ;
$solutionUpdate | Update-XrmRecord;

# Export solution as managed to local folder
$solutionFilePath = Export-XrmSolution -SolutionUniqueName $mySolutionUniqueName -Managed $true -ExportPath $PSScriptRoot;



Write-Host "END"
