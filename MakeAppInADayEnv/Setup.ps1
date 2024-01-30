#
#
#  Run  Start-AppInADay-Setup 
#
#  V1.0 - 10/29/2019 - inital version
#  v1.1 - 11/30/2019 - changed default office license to E3
#  V1.2 - 01/22/2020 - changed default EnvSku to Trial on Reset / Resume
#  V1.3 - 01/23/2020 - Infer admin api url from region, add small delay after ad group create
#  V1.4 - 07/01/2020 - Allow run without creating Dataverse using -CreateDataverse:$false
#  V1.5 - 05/10/2021 - Allow removal of prior lab admin users and environments
#  V1.6 - 08/20/2021 - -RequiredVersion 2.0.126  to work around auth issue in latest version
#  V1.7 - 08/30/2021 - Removed required version
#  V1.8 - 04/04/2023 - Best Practices cleanup
#  V1.9 - 05/03/2023 - Fixed a couple of problems introduced in cleanup
#  V2.0 - 08/07/2023 - Updated to use Microsoft.Graph
#  V2.1 - 10/26/2023 - Automatically detect Dataverse location
#
####

$LabAdminPrefix = "labadmin";
$LabAdminPassword = "test@word1"

#For Microsoft E3 use SPE_E3
#For Microsoft E5 use SPE_E5
$LabAdminOfficeLicense = "SPE_E5"
$LabAdminPowerLicense = "POWERAPPS_PER_USER"
   

####
#   End of the configuration section
####
Write-Host "Installing Az.Accounts..."
Install-Module Az.Accounts -Scope CurrentUser

Write-Host "Installing Microsoft.Graph.Authentication module..."
Install-Module Microsoft.Graph.Authentication -Scope CurrentUser

Write-Host "Installing Microsoft.Graph.Users module..."
Install-Module Microsoft.Graph.Users -Scope CurrentUser

Write-Host "Installing Microsoft.Graph.Groups module..."
Install-Module Microsoft.Graph.Groups -Scope CurrentUser

Write-Host "Installing Microsoft.Graph.Identity.DirectoryManagement module..."
Install-Module Microsoft.Graph.Identity.DirectoryManagement -Scope CurrentUser

Write-Host "Installing Microsoft.Graph.Users.Actions module..."
Install-Module Microsoft.Graph.Users.Actions -Scope CurrentUser

Write-Host "Installing Administration.PowerShell module..."
Install-Module -Name Microsoft.PowerApps.Administration.PowerShell -Scope CurrentUser -Force 

Write-Host "Installing Microsoft.PowerApps.PowerShell module..."
Install-Module -Name Microsoft.PowerApps.PowerShell  -Scope CurrentUser -AllowClobber -Force 

Write-Host "Installing OnlineManagementAPI module..."
Install-Module Microsoft.Xrm.OnlineManagementAPI -Scope CurrentUser

Write-Host "Installing Powershell module..."
Install-Module -Name Microsoft.Xrm.Data.Powershell -Scope CurrentUser

Write-Host "Installing PowerShell.Utility  module..."
Import-Module Microsoft.PowerShell.Utility 

Write-Host "Done installing all modules..."



Write-Host "### Prepare to run Start-AppInADay-Setup ###" 
Write-Host ""
Write-Host "  Start-AppInADay-Setup -TenantName 'MX60265ABC' -UserCount 10 "-ForegroundColor Green     
Write-Host "  Parameters details for Start-AppInADay-Setup:"
Write-Host "     TenantName : This is the name portion of name.onmicrosoft.com" -ForegroundColor Green  
Write-Host "     DataverseLocation: This must match be appropriate for Region e.g. US = unitedstates"  -ForegroundColor Green
Write-Host "     UserCount: This is a number between 1 and 75 that is attending your event"  -ForegroundColor Green
Write-Host "     You can find out your tenant region by running running Get-MsolCompanyInformation and looking at CountryLetterCode" -ForegroundColor Green
Write-Host ""
Write-Host "### Ready for you to run Start-AppInADay-Setup ###" 

# Start-AppInADay-Setup -TenantName M365x72172227 -UserCount 10

function Start-AppInADay-Setup {
    <#
    .SYNOPSIS 
      Configure a tenant for running an App in a day workshop
    .EXAMPLE
     Start-AppInADay-Setup -TenantName 'MX60265ABC'  -UserCount 10 
     
     TenantName : This is the name portion of name.onmicrosoft.com     
     DataverseLocation: This must match be appropriate for Region e.g. US = unitedstates
     UserCount: This is a number between 1 and the max you have licenses for
     UserStartCount: This defaults to 1, but can allow you to start user number at higher value e.g, 20 would start with labadmin20
     APIUrl : You can find the url for your region here if not in US - https://docs.microsoft.com/en-us/dynamics365/customer-engagement/developer/online-management-api/get-started-online-management-api
     Solution : This allows you to specify a Dataverse Solution that will be pre-loaded into each student environment
     EnvSKU: This can be either Trial or Production, default is Trial
     DeleteUsers: This will delete/disable all other uses besides the one that runs this script - use $true to enable - default is $false
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$TenantName,
        [Parameter(Mandatory = $false)]
        [string]$Dataverselocation = "",
        [Parameter(Mandatory = $true)]
        [int]$UserCount = 1,
        [Parameter(Mandatory = $false)]
        [string]$APIUrl = "https://admin.services.crm.dynamics.com",
        [Parameter(Mandatory = $false)]
        [string]$Solution,
        [Parameter(Mandatory = $false)]
        [string]$EnvSKU = "Trial",
        [Parameter(Mandatory = $false)]
        [switch]$DeleteUsers = $false,
        [Parameter(Mandatory = $false)]
        [bool]$CreateDataverse = $true,
        [Parameter(Mandatory = $false)]
        [int]$UserStartCount = 1
    )

    Write-Host "Setup Starting"

    

    # $DomainName =$Tenant + ".onmicrosoft.com"

    $UserCredential = Get-Credential

    $azParam = @{
          Credential = $UserCredential
          Force      = $true
      }
    Connect-AzAccount @azParam
    $token = (Get-AzAccessToken -ResourceTypeName MSGraph -ErrorAction Stop).token
    $token = ConvertTo-SecureString $token -AsPlainText -Force

    Write-Host "Connecting to Microsoft Graph..."
  
    Connect-MgGraph  -AccessToken $token -ErrorAction Stop
    
    Write-Host "Connecting to PowerApps..."
    try {
        Add-PowerAppsAccount -Username $UserCredential.UserName -Password $UserCredential.Password
    }
    catch { 
        Write-Host "Error connecting to PowerApps, if error includes `Cannot find overload for UserCredential` please run CleanupOldModules.ps1 and retry this script"
        Read-Host -Prompt 'Press <Enter> to exit, then restart script with proper information'
        exit
    }

        
    $companyInfo = Get-MgOrganization



    if ([string]::IsNullOrWhiteSpace($Dataverselocation)) {   
      #$Dataverselocation = Get-PowerPlatformRegion -CountryLetterCode "CC"
      $Dataverselocation = Get-PowerPlatformRegion -CountryLetterCode $companyInfo.CountryLetterCode 
    }

    if ([string]::IsNullOrWhiteSpace($Dataverselocation)) {   
       Write-Host "Error determaning Dataverse location, please provide DataverseLocation parameter"
       Read-Host -Prompt 'Press <Enter> to exit, then restart script with proper information'
       exit
    }


    Write-Host "Tenant:" $TenantName
    $Tenant = $TenantName;
    Write-Host "Region:" $Region
    # $TenantRegion = $Region;
    Write-Host "API Url:" $APIUrl
    $AdminAPIUrl = Get-AdminServiceUrl -Dataverselocation $Dataverselocation  -APIUrl $APIUrl
    Write-Host "Dataverse Location:" $Dataverselocation
    Write-Host "User Count:" $UserCount
    $LabAdminCount = $UserCount

    if ($DeleteUsers) {
        $confirmDelete = Read-Host -Prompt 'Confirm disabling all lab admin account and environments (Y/N)'
        if ($confirmDelete -and $confirmDelete -eq 'Y') {
            Write-Host "Proceeding to disable all lab admin users"
            Reset-AppInADay -TenantName $TenantName -Dataverselocation $Dataverselocation -DeleteUsers $true
            Write-Host "Delaying to allow cleanup to finish"
            Start-Sleep 15
        }
    }


    if (Test-Licenses -Tenant $Tenant) {     
        
        Add-LabAdminUsers -Tenant $Tenant -Count $LabAdminCount -TenantRegion $companyInfo.CountryLetterCode -password $LabAdminPassword  -userprefix $LabAdminPrefix -startCount $UserStartCount   
        Write-Host "Delaying to allow user creation to finish"
        Start-Sleep 15
        Add-LabAdminToGroup

        Add-PowerAppsAccount -Username $UserCredential.UserName -Password $UserCredential.Password
       

        if ($CreateDataverse) {

            New-DataverseEnvironment -namePrefix "Dev - " -Dataverselocation $Dataverselocation -password $LabAdminPassword -EnvSKU $EnvSKU     
            
            
            $users = Get-MgUser -All | Where-Object { $_.UserPrincipalName -like 'labadmin*' } | Sort-Object UserPrincipalName

            Wait-ForEnvProvisioning -namePrefix "Dev - " -envCount $users.count

            New-DataverseDatabases -namePrefix "Dev - "

            if ($EnvSKU -ne "Trial") {
                Add-LabAdminToSysAdmin -namePrefix "Dev - "     
            }

            Install-SolutionFile-ToEnv -nameprefix "Dev - " -solution $Solution -APIUrl $AdminAPIUrl
        } 
    }
    else {
        Write-Host "Your current licensed skus are:"
        Get-MgSubscribedSKU
        Write-Host "Fix your licenses and then restart"
    }
        

    Write-Host "Setup Ending"
}

function Reset-AppInADay {
    <#
    .SYNOPSIS 
      This will delete all existing student environments and then create new ones
    .EXAMPLE
     Reset-AppInADay -TenantName 'MX60265ABC'
     
     TenantName : This is the name portion of name.onmicrosoft.com     
     DataverseLocation: This must match be appropriate for Region e.g. US = unitedstates     
     Solution : This allows you to specify a Dataverse Solution that will be pre-loaded into each student environment
     EnvSKU: This can be either Trial or Production, default is Trial     
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$TenantName,
        [Parameter(Mandatory = $false)]
        [string]$Dataverselocation = "",   
        [Parameter(Mandatory = $false)]
        [string]$APIUrl = "https://admin.services.crm.dynamics.com",
        [Parameter(Mandatory = $false)]
        [string]$Solution,
        [Parameter(Mandatory = $false)]
        [string]$EnvSKU = "Trial"
    )

    Write-Host "Reset Starting"


   
    $companyInfo = Get-MgOrganization

    if ([string]::IsNullOrWhiteSpace($Dataverselocation)) {   
      $Dataverselocation = Get-PowerPlatformRegion -CountryLetterCode $companyInfo.CountryLetterCode 
    }

    if ([string]::IsNullOrWhiteSpace($Dataverselocation)) {   
       Write-Host "Error determaning Dataverse location, please provide DataverseLocation parameter"
       Read-Host -Prompt 'Press <Enter> to exit, then restart script with proper information'
       exit
    }

    Write-Host "Tenant:" $TenantName
    # $Tenant = $TenantName;
    Write-Host "Region:" $Region
    # $TenantRegioin = $Region;
    Write-Host "API Url:" $APIUrl
    $AdminAPIUrl = Get-AdminServiceUrl -Dataverselocation $Dataverselocation  -APIUrl $APIUrl
    Write-Host "Dataverse Location:" $Dataverselocation

    
    # $DomainName =$Tenant + ".onmicrosoft.com"

    $UserCredential = Get-Credential

    $azParam = @{
          Credential = $UserCredential
          Force      = $true
      }
    Connect-AzAccount @azParam
    $token = (Get-AzAccessToken -ResourceTypeName MSGraph -ErrorAction Stop).token
    $token = ConvertTo-SecureString $token -AsPlainText -Force

    Write-Host "Connecting to Microsoft Graph..."
  
    Connect-MgGraph  -AccessToken $token -ErrorAction Stop

    Write-Host "Connecting to PowerApps..."
    try {
        Add-PowerAppsAccount -Username $UserCredential.UserName -Password $UserCredential.Password
    }
    catch { 
        Write-Host "Error connecting to PowerApps, if error includes Cannot find overload for UserCredential please run CleanupOldModules.ps1 and retry this script"
        Read-Host -Prompt 'Press <Enter> to exit, then restart script with proper information'
        exit
    }
    
        
    # $companyInfo = Get-MsolCompanyInformation        
                            

    Add-PowerAppsAccount -Username $UserCredential.UserName -Password $UserCredential.Password

    Remove-DataverseEnvironment -namePrefix "Dev - "

    Wait-ForDataverseDeleting -namePrefix "Dev - "
        
    New-DataverseEnvironment -namePrefix "Dev - " -Dataverselocation $Dataverselocation -password $LabAdminPassword -EnvSKU $EnvSKU

    Add-PowerAppsAccount -Username $UserCredential.UserName -Password $UserCredential.Password
        
    New-DataverseDatabases -namePrefix "Dev - "

        
    if ($EnvSKU -ne "Trial") {
        Add-LabAdminToSysAdmin -namePrefix "Dev - "     
    }

    Install-SolutionFile-ToEnv -nameprefix "Dev - " -solution $Solution -APIUrl $AdminAPIUrl
          

    Write-Host "Setup Ending"
}

function Reset-AppInADay {
    <#
    .SYNOPSIS 
      This will delete all existing student environments 
    .EXAMPLE
     Reset-AppInADay -TenantName 'MX60265ABC'   -DeleteUsers 
     
     TenantName : This is the name portion of name.onmicrosoft.com     
     APIUrl : You can find the url for your region here if not in US - https://docs.microsoft.com/en-us/dynamics365/customer-engagement/developer/online-management-api/get-started-online-management-api
     DeleteUsers : True or False - use this to delete all labadmin users
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$TenantName,  
        [Parameter(Mandatory = $false)]
        [string]$APIUrl = "https://admin.services.crm.dynamics.com",
        [Parameter(Mandatory = $false)]
        [switch] $DeleteUsers = $false,
        [Parameter(Mandatory = $false)]
        [string]$Dataverselocation = ""
    )

    Write-Host "cleanup Starting"


     $companyInfo = Get-MgOrganization

    if ([string]::IsNullOrWhiteSpace($Dataverselocation)) {   
      $Dataverselocation = Get-PowerPlatformRegion -CountryLetterCode $companyInfo.CountryLetterCode 
    }

    if ([string]::IsNullOrWhiteSpace($Dataverselocation)) {   
       Write-Host "Error determaning Dataverse location, please provide DataverseLocation parameter"
       Read-Host -Prompt 'Press <Enter> to exit, then restart script with proper information'
       exit
    }


    Write-Host "Tenant:" $TenantName
    # $Tenant = $TenantName;
    Write-Host "Region:" $Region
    # $TenantRegioin = $Region;
    Write-Host "API Url:" $APIUrl
    # $AdminAPIUrl = Get-AdminServiceUrl -Dataverselocation $Dataverselocation  -APIUrl $APIUrl
    Write-Host "Dataverse Location:" $Dataverselocation

    
    # $DomainName =$Tenant + ".onmicrosoft.com"
    if ($null -eq $UserCredential) {
        $UserCredential = Get-Credential
    }

   $azParam = @{
          Credential = $UserCredential
          Force      = $true
      }
    Connect-AzAccount @azParam
    $token = (Get-AzAccessToken -ResourceTypeName MSGraph -ErrorAction Stop).token
    $token = ConvertTo-SecureString $token -AsPlainText -Force

    Write-Host "Connecting to Microsoft Graph..."
  
    Connect-MgGraph  -AccessToken $token -ErrorAction Stop
    Write-Host "Connecting to PowerApps..."
    try {
        Add-PowerAppsAccount -Username $UserCredential.UserName -Password $UserCredential.Password
    }
    catch { 
        Write-Host "Error connecting to PowerApps, if error includes Cannot find overload for UserCredential please run CleanupOldModules.ps1 and retry this script"
        Read-Host -Prompt 'Press <Enter> to exit, then restart script with proper information'
        exit
    }
    
        
    # $companyInfo = Get-MsolCompanyInformation                                    

    Add-PowerAppsAccount -Username $UserCredential.UserName -Password $UserCredential.Password

    Remove-DataverseEnvironment -namePrefix "Dev - "
                
    Wait-ForDataverseDeleting -namePrefix "Dev - "

    if ($DeleteUsers) {
        Remove-LabAdminUsers
    }

    Write-Host "Cleanup Ending"
}

function Remove-LabAdminUsers {

    Write-Host "***Removing LabAdmin Users ****" -ForegroundColor Green

    $users = Get-MgUser -All | Where-Object { $_.UserPrincipalName -like 'labadmin*' }
   ForEach ($user in $users) {
      Remove-MgUser -UserId $user.Id
      Write-Host "****Deleted " $user.UserPrincipalName " ****" -ForegroundColor Green
    }


    Write-Host "****Old Users Deleted ****" -ForegroundColor Green
    Get-MgUser | Format-List displayname, licenses

}

function Resume-AppInADay-DataverseProvisioning {
    <#
    .SYNOPSIS 
      This will resume provisioning student environments in case the inital script has to be restarted
    .EXAMPLE
     Resume-AppInADay-DataverseProvisioning -TenantName 'MX60265ABC'
     
     TenantName : This is the name portion of name.onmicrosoft.com     
     DataverseLocation: This must match be appropriate for Region e.g. US = unitedstates     
     APIUrl : You can find the url for your region here if not in US - https://docs.microsoft.com/en-us/dynamics365/customer-engagement/developer/online-management-api/get-started-online-management-api
     Solution : This allows you to specify a Dataverse Solution that will be pre-loaded into each student environment
     EnvSKU: This can be either Trial or Production, default is Trial     
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$TenantName,
        [Parameter(Mandatory = $false)]
        [string]$Dataverselocation = "",   
        [Parameter(Mandatory = $false)]
        [string]$APIUrl = "https://admin.services.crm.dynamics.com",
        [Parameter(Mandatory = $false)]
        [string]$Solution,
        [Parameter(Mandatory = $false)]
        [string]$EnvSKU = "Trial"
    )
    Write-Host "Resume Starting"


    $companyInfo = Get-MgOrganization

    if ([string]::IsNullOrWhiteSpace($Dataverselocation)) {   
      $Dataverselocation = Get-PowerPlatformRegion -CountryLetterCode $companyInfo.CountryLetterCode 
    }

    if ([string]::IsNullOrWhiteSpace($Dataverselocation)) {   
       Write-Host "Error determaning Dataverse location, please provide DataverseLocation parameter"
       Read-Host -Prompt 'Press <Enter> to exit, then restart script with proper information'
       exit
    }

    Write-Host "Tenant:" $TenantName
    # $Tenant = $TenantName;
    Write-Host "Region:" $Region
    # $TenantRegioin = $Region;
    Write-Host "API Url:" $APIUrl
    $AdminAPIUrl = Get-AdminServiceUrl -Dataverselocation $Dataverselocation  -APIUrl $APIUrl
    Write-Host "Admin Url:" $AdminAPIUrl
    Write-Host "Dataverse Location:" $Dataverselocation

    # $DomainName =$Tenant + ".onmicrosoft.com"

    $UserCredential = Get-Credential

    $azParam = @{
          Credential = $UserCredential
          Force      = $true
      }
    Connect-AzAccount @azParam
    $token = (Get-AzAccessToken -ResourceTypeName MSGraph -ErrorAction Stop).token
    $token = ConvertTo-SecureString $token -AsPlainText -Force

    Write-Host "Connecting to Microsoft Graph..."
  
    Connect-MgGraph  -AccessToken $token -ErrorAction Stop
    Write-Host "Connecting to PowerApps..."
    try {
        Add-PowerAppsAccount -Username $UserCredential.UserName -Password $UserCredential.Password
    }
    catch { 
        Write-Host "Error connecting to PowerApps, if error includes Cannot find overload for UserCredential please run CleanupOldModules.ps1 and retry this script"
        Read-Host -Prompt 'Press <Enter> to exit, then restart script with proper information'
        exit
    }
    
        
    # $companyInfo = Get-MsolCompanyInformation                                    

    Add-PowerAppsAccount -Username $UserCredential.UserName -Password $UserCredential.Password

    New-DataverseEnvironment -namePrefix "Dev - " -Dataverselocation $Dataverselocation -password $LabAdminPassword -EnvSKU $EnvSKU

    Add-PowerAppsAccount -Username $UserCredential.UserName -Password $UserCredential.Password
        
    New-DataverseDatabases -namePrefix "Dev - "

    if ($EnvSKU -ne "Trial") {
        Add-LabAdminToSysAdmin -namePrefix "Dev - "     
    }

    Install-SolutionFile-ToEnv -nameprefix "Dev - " -solution $Solution -APIUrl $AdminAPIUrl
         

    Write-Host "Setup Ending"
}

function Test-Licenses {
    param(  
        [Parameter(Mandatory = $true)]
        [string]$Tenant 
    )
    
    $licensesGood = $true

    $skus = Get-MgSubscribedSKU

    $PowerAppsSku = $skus.where({ $_.SkuPartNumber -eq $LabAdminPowerLicense }) 
    $OfficeSku = $skus.where({ $_.SkuPartNumber -eq $LabAdminOfficeLicense })

    
    if ($null -eq $PowerAppsSku -or $PowerAppsSku.Count -eq 0) {
        Write-Host "No License in tenant for LabAdminPowerLicense " $LabAdminPowerLicense " Add license or change sku before you continue" -ForegroundColor red
        $licensesGood = $false
    }
    
    if ($null -eq $OfficeSku -or $OfficeSku.Count -eq 0) {
        Write-Host "No License in tenant for LabAdminOfficeLicense " $LabAdminOfficeLicense " Add license or change sku before you continue" -ForegroundColor red
        $licensesGood = $false
    }

    return $licensesGood
}

function Add-LabAdminUsers {
    param
    (
        [Parameter(Mandatory = $true)]
        [string]$Tenant,
        [Parameter(Mandatory = $true)]
        [int]$Count,
        [Parameter(Mandatory = $false)]
        [string]$TenantRegion = "GB",
        [Parameter(Mandatory = $false)]
        [string]$password = $LabAdminPassword,
        [Parameter(Mandatory = $false)]
        [string]$userprefix = "labadmin",
        [Parameter(Mandatory = $false)]
        [int]$startCount = 1,
        [Parameter(Mandatory = $false)]
        [string]$powerLicense = $LabAdminPowerLicense
    
    )

    $DomainName = $Tenant + ".onmicrosoft.com"


    Write-Host "Adding Admin Users"
    Write-Host "Tenant: " $Tenant
    Write-Host "Domain Name: " $DomainName
    Write-Host "Number of users to create: " $Count
    
    Write-Host "TenantRegion: " $TenantRegion
    Write-Host "Dataverse location: " $Dataverselocation
    Write-Host "password: " $password

    $skus = Get-MgSubscribedSKU

    $PowerAppsSku = $skus.where({ $_.SkuPartNumber -eq $LabAdminPowerLicense }) 
    $OfficeSku = $skus.where({ $_.SkuPartNumber -eq $LabAdminOfficeLicense })
  
    # $securepassword = ConvertTo-SecureString -String $password -AsPlainText -Force
    
 
    Write-Host "Creating users " -ForegroundColor Green
   
   $PasswordProfile = @{
  Password = $LabAdminPassword
  ForceChangePasswordNextSignIn = $False
  }

    for ($i = $startCount; $i -lt ($startCount + $Count); $i++) {
        $firstname = "Lab"
        $lastname = "Admin" + $i
        $displayname = "Lab Admin " + $i
        $email = ($userprefix + $i + "@" + $DomainName).ToLower()
        
        $MailNickname = ($userprefix + $i).ToLower()

        
        $existingUser = Get-MgUser -UserId $email -ErrorAction SilentlyContinue

        if ($Null -eq $existingUser) {
            

            
            $newUser = New-MgUser -GivenName $firstname -Surname $lastname -DisplayName $displayname -MailNickname $MailNickname -PasswordProfile $PasswordProfile -UsageLocation $TenantRegion -AccountEnabled  -UserPrincipalName $email

            Write-Host "Created new user " $displayname
        }

        if ($null -ne $LabAdminOfficeLicense -and $null -ne $LabAdminPowerLicense) {
        
                $licenseResults = Set-MgUserLicense -UserId $email -AddLicenses @{SkuId = $PowerAppsSku.SkuId} -RemoveLicenses @()
                $licenseResults = Set-MgUserLicense -UserId $email -AddLicenses @{SkuId = $OfficeSku.SkuId} -RemoveLicenses @()

                Write-Host "Office and Power Apps Licenses Assigned to user " $displayname
            }

         Start-Sleep -s 2
    }
    Write-Host "*****************Lab Users Created ***************" -ForegroundColor Green
    $userQuery = $LabAdminPrefix + '*'

    Get-MgUser | Where-Object { $_.UserPrincipalName -like $userQuery } | Format-List displayname, licenses

}

function Add-LabAdminToGroup {

    Write-Host "Begin adding [labadmin] user to Lab Admin Team group"

    $userprefix = $LabAdminPrefix + '*'

    $adminGroup = get-MGGroup | Where-Object { $_.DisplayName -eq "Lab Admin Team" } | Select-Object -first 1

    if (!$adminGroup) {        
        $adminGroup = New-MgGroup -DisplayName "Lab Admin Team" -MailEnabled:$False -MailNickName "LabAdminTeam" -SecurityEnabled
        Write-Host "Created new group " $adminGroup.ObjectId
        write-host "Short delay to allow group creation to finish..."
        Start-Sleep -s 15
    }
    else {
        Write-Host "Found existing group " $adminGroup.Id
    }
   
   
    $users = Get-MgUser -All | Where-Object { $_.UserPrincipalName -like $userprefix } | Sort-Object UserPrincipalName

    $existingMembers = Get-MgGroupMember -GroupId $adminGroup.Id | Select-Object -ExpandProperty UserPrincipalName


    ForEach ($user in $users) { 

        if (!$existingMembers -contains $user.UserPrincipalName) {

            write-host "adding user "  $user.UserPrincipalName  " to group "  $adminGroup.DisplayName

            New-MGGroupMember -GroupId $adminGroup.Id -DirectoryObjectId $user.Id
        }
        else {
            write-host "User "  $user.UserPrincipalName  " is already a member of "  $adminGroup.Id
        }

        
    }
    Write-Host "Ending add labadmin users to Lab Admin Team group"
}

function Install-SolutionFile-ToEnv {
    param(
        [Parameter(Mandatory = $false)]
        [string]$namePrefix = "Central Apps Test - ",
        [Parameter(Mandatory = $false)]
        [string]$solution,
        [Parameter(Mandatory = $false)]
        [string]$APIUrl = "https://admin.services.crm.dynamics.com"   
    )


    Write-Host "Starting import of starting solution"
    
    if ($solution -ne "" -and $null -ne $solution) {
   
        $dataverseInstances = Get-CrmInstances -ApiUrl $APIUrl -Credential $UserCredential 

        $envQuery = '*' + $namePrefix + '*'
        $envlist = $dataverseInstances.Where({ $_.EnvironmentType -ne 'Default' }).Where({ $_.FriendlyName -like $envQuery })

        Write-Host "Found " $envlist.Count " environments to process"

        ForEach ($environment in $envlist) { 
     
            Write-Host "Processing environment :" $environment.FriendlyName


            $conn = Connect-CrmOnline -Credential $UserCredential -ServerUrl $environment.ApplicationUrl
             
    
            $solutionPath = $PSScriptRoot + "\" + $solution

            Write-Host "Importing " $solutionPath

            try {

                Import-CrmSolution -conn $conn -SolutionFilePath $solutionPath -PublishChanges $true
            }
            Catch {
                $ErrorMessage = $_.Exception.Message        
                if ($ErrorMessage -like '*timeout*' -or $ErrorMessage -like '*Underlying connection was closed*' ) { 
                    write-host "  retrying import due to timeout after short delay"
                    Start-Sleep -s 30
                    Import-CrmSolution -conn $conn -SolutionFilePath $solutionPath -Verbose -PublishChanges $true
                }
                else {
                    write-host $ErrorMessage -ForegroundColor Red
                }
                
        
            }
    
        }   
    }
     
   
    Write-Host "Ending import of starting solution"
}

function Test-SolutionFileToEnv {
    param(
        [Parameter(Mandatory = $false)]
        [string]$namePrefix = "Central Apps Test - ",
        [Parameter(Mandatory = $false)]    
        [string]$uniquename,
        [Parameter(Mandatory = $false)]
        [string]$APIUrl = "https://admin.services.crm.dynamics.com"   
    )


    Write-Host "Starting verify solution"
    
    
   
    $dataverseInstances = Get-CrmInstances -ApiUrl $APIUrl -Credential $UserCredential 

    $envQuery = '*' + $namePrefix + '*'
    $envlist = $dataverseInstances.Where({ $_.EnvironmentType -ne 'Default' }).Where({ $_.FriendlyName -like $envQuery })

    Write-Host "Found " $envlist.Count " environments to process"

    ForEach ($environment in $envlist) { 
     
        Write-Host "Processing environment :" $environment.FriendlyName


        $conn = Connect-CrmOnline -Credential $UserCredential -ServerUrl $environment.ApplicationUrl
                                      

        $solutionList = Get-CrmRecords `
            -EntityLogicalName solution `
            -Fields uniquename `
            -conn $conn

        $sol = $solutionList.CrmRecords.Where({ $_.uniquename -eq $uniquename })
        if ($sol.Count -eq 1) {
            Write-Host "   Solution verified" -ForegroundColor Green
        }
        else {
            Write-Host "   Solution Not Found:" $environment.FriendlyName -ForegroundColor Red
        }
    
    }   
    
     
   
    Write-Host "Ending import of starting solution"
}

function New-DataverseEnvironment {

    param(
        [Parameter(Mandatory = $false)]
        [string]$namePrefix = "Central Apps Test - ",
        [Parameter(Mandatory = $false)]
        [string]$password = $LabAdminPassword,
        [Parameter(Mandatory = $false)]
        [string]$Dataverselocation = "",
        [Parameter(Mandatory = $false)]
        [string]$EnvSKU = "Trial"
    )

    $userprefix = $LabAdminPrefix + '*'

    $starttime = Get-Date -DisplayHint Time
    Write-Host " Starting create Dataverse environment :" $starttime   -ForegroundColor Green

   $securepassword = ConvertTo-SecureString -String $password -AsPlainText -Force
    
    $users = Get-MgUser -All | Where-Object { $_.UserPrincipalName -like $userprefix } | Sort-Object UserPrincipalName

    $allEnvList = @(Get-AdminPowerAppEnvironment)

    $companyInfo = Get-MgOrganization

    if ([string]::IsNullOrWhiteSpace($Dataverselocation)) {   
      $Dataverselocation = Get-PowerPlatformRegion -CountryLetterCode $companyInfo.CountryLetterCode 
    }

    if ([string]::IsNullOrWhiteSpace($Dataverselocation)) {   
       Write-Host "Error determaning Dataverse location, please provide DataverseLocation parameter"
       Read-Host -Prompt 'Press <Enter> to exit, then restart script with proper information'
       exit
    }
    
    ForEach ($user in $users) { 
        $envDev = $null
        # $envProd = $null

        if ($user.isLicensed -eq $false) {
            write-host " skiping user " $user.UserPrincipalName " they are not licensed" -ForegroundColor Red
            continue
        }

        if ($EnvSKU -eq "Trial") {
            write-host " Switching to user " $user.UserPrincipalName 

            Add-PowerAppsAccount -Username $user.UserPrincipalName -Password $securepassword -Verbose
        }

        write-host " Creating environment for user " $user.UserPrincipalName 
         
        $envDisplayname = $namePrefix + $user.UserPrincipalName.Split('@')[0] 
        $envDisplayname

        $envQuery = $envDisplayname + "*"
         
        $envDevList = @($allEnvList.where( { $_.DisplayName -like $envQuery }))         
        
        if ($envDevList.count -eq 0 ) { 
       
            $envDev = New-AdminPowerAppEnvironment -DisplayName  $envDisplayname -LocationName $Dataverselocation -EnvironmentSku $EnvSKU -Verbose 
            
       
            Write-Host " Created Dataverse Environment with id :" $envDev.DisplayName   -ForegroundColor Green 
        }
        else {
            Write-Host " Skipping Dataverse Environment with id :" $envDisplayname " it already exists"  -ForegroundColor Green 
        }
             
         
    }
    if ($EnvSKU -eq "Trial") {
        write-host " switching back to user " $UserCredential.UserName 

        Add-PowerAppsAccount -Username $UserCredential.UserName -Password $UserCredential.Password
    }
    $endtime = Get-Date -DisplayHint Time
    $duration = $("{0:hh\:mm\:ss}" -f ($endtime - $starttime))
    Write-Host "End of create Dataverse environment at : " $endtime "  Duration: " $duration   -ForegroundColor Green

}

function New-DataverseDatabases {
    param(
        [Parameter(Mandatory = $false)]
        [string]$namePrefix = "Central Apps"
    )

    $searchPrefix = '*' + $namePrefix + '*'

    $starttime = Get-Date -DisplayHint Time
    Write-Host "Starting create Dataverse databases :" $starttime   -ForegroundColor Green

    $DataverseEnvs = Get-AdminPowerAppEnvironment | Where-Object { $_.DisplayName -like $searchPrefix -and $_.commonDataServiceDatabaseType -eq "none" } | Sort-Object displayname
              
        
    Write-Host "creating Dataverse databases for following environments :
          " $DataverseEnvs.DisplayName "
        ****************************************************************
        ****************************************************************" -ForegroundColor Green

    ForEach ($DataverseEnv in $DataverseEnvs) { 
        $DataverseEnv.EnvironmentName
        Write-Host "creating Dataverse databases for:" $DataverseEnv.DisplayName " id:" $DataverseEnv.EnvironmentName -ForegroundColor Green
           
        New-AdminPowerAppCdsDatabase -EnvironmentName  $DataverseEnv.EnvironmentName -CurrencyName USD -LanguageName 1033  -ErrorAction Continue -WaitUntilFinished $false   -Templates @(“D365_CDSSampleApp“)
           
    }

    Wait-ForDataverseProvisioning -namePrefix $namePrefix


    $endtime = Get-Date -DisplayHint Time
    $duration = $("{0:hh\:mm\:ss}" -f ($endtime - $starttime))
    Write-Host "End of create Dataverse database at : " $endtime "  Duration: " $duration   -ForegroundColor Green
        
}

function Wait-ForEnvProvisioning {

    param(
        [Parameter(Mandatory = $false)]
        [string]$namePrefix = "Central Apps",
        [Parameter(Mandatory = $true)]
        [int]$envCount
    )

    $searchPrefix = '*' + $namePrefix + '*'

    Write-host "Checking on provisioning status of environments"
    Do {
            
        $DataverseEnvs = @(Get-AdminPowerAppEnvironment | Where-Object { $_.DisplayName -like $searchPrefix })         
            
            
        if ($DataverseEnvs.count -ne $envCount) {
            Write-Host "There are" $DataverseEnvs.count "environments of $envCount - Waiting 30 seconds "
            Start-Sleep -s 30
        }
    } While ($DataverseEnvs.count -ne $envCount)
}

function Wait-ForDataverseProvisioning {

    param(
        [Parameter(Mandatory = $false)]
        [string]$namePrefix = "Central Apps"
    )

    $searchPrefix = '*' + $namePrefix + '*'

    Write-host "Checking on provisioning status of Dataverse"
    Do {
            
        $DataverseEnvs = @(Get-AdminPowerAppEnvironment | Where-Object { $_.DisplayName -like $searchPrefix -and $_.CommonDataServiceDatabaseProvisioningState -ne "Succeeded" })         
            
            
        if ($DataverseEnvs.count -gt 0) {
            Write-Host "There are" $DataverseEnvs.count "Dataverse provisionings left - Waiting 30 seconds "
            Start-Sleep -s 30
        }
    } While ($DataverseEnvs.count -gt 0)
}

function Wait-ForDataverseDeleting {

    param(
        [Parameter(Mandatory = $false)]
        [string]$namePrefix = "Central Apps"
    )

    $searchPrefix = '*' + $namePrefix + '*'

    Write-host "Checking on delete status of Dataverse"
    Do {
            
        $DataverseEnvs = @(Get-AdminPowerAppEnvironment | Where-Object { $_.DisplayName -like $searchPrefix })         
            
            
        if ($DataverseEnvs.count -gt 0) {
            Write-Host "There are" $DataverseEnvs.count "Dataverse removals left - Waiting 30 seconds "
            Start-Sleep -s 30
        }
    } While ($DataverseEnvs.count -gt 0)
}

function Add-LabAdminToSysAdmin {

    param(
        [Parameter(Mandatory = $false)]
        [string]$namePrefix = "Central Apps Test - "
    )

    Write-Host "Starting add lab admin to test environment as sysadmin"

    $role = 'System Administrator'

    $DataverseInstances = Get-CrmInstances -ApiUrl $AdminAPIUrl -Credential $UserCredential 

    $searchPrefix = '*' + $namePrefix + '*'

    $envlist = $DataverseInstances.Where({ $_.EnvironmentType -ne 'Default' }).Where({ $_.FriendlyName -like $searchPrefix })

    Write-Host "Found " $envlist.count " environments to process"

    ForEach ($environment in $envlist) { 
     
        Write-Host "Processing environment :" $environment.FriendlyName


        $conn = Connect-CrmOnline -Credential $UserCredential -ServerUrl $environment.ApplicationUrl

        #        $conn.IsReady,$conn.ConnectedOrgFriendlyName
    
   
        $users = Get-CrmRecords `
            -EntityLogicalName systemuser `
            -Fields domainname, systemuserid, fullname `
            -conn $conn
              
        $compareString = $conn.ConnectedOrgFriendlyName -replace $namePrefix, "*" 
        $compareString = $compareString + "@*"
        Write-Host "comparing("$compareString")"

        $selectedUsers = $users.CrmRecords | Where-Object { $_.domainname -like $compareString } | Sort-Object domainname

        Write-Host "Found "$selectedUsers.count " users to process"

        ForEach ($user in $selectedUsers) { 

            write-host "  adding user "$user.fullname" to group sysadmin"

            try {
                Add-CrmSecurityRoleToUser `
                    -UserId $user.systemuserid `
                    -SecurityRoleName $role `
                    -conn $conn

                write-host "  added user "  $user.fullname  " to group sysadmin"

            }
            Catch {
                $ErrorMessage = $_.Exception.Message        
                if ($ErrorMessage -like '*Cannot insert duplicate key*') { 
                    write-host "  Skipping user "  $user.fullname  " already a member"
                }
                else {
                    write-host $ErrorMessage -ForegroundColor Red
                }
                
        
            }
        
        } #foreach user

    
    }   #foreach env
    Write-Host "Ending add lab admin to test environment as sysadmin"
}

function Get-AdminServiceUrl {
    param(   
        [Parameter(Mandatory = $false)]
        [string]$Dataverselocation = "",
        [Parameter(Mandatory = $false)]
        [string]$APIUrl = "https://admin.services.crm.dynamics.com"
    )
    $result = switch ( $Dataverselocation ) {
        "unitedstates" { 'https://admin.services.crm.dynamics.com' }
        "southamerica" { 'https://admin.services.crm2.dynamics.com' }
        "canada" { 'https://admin.services.crm3.dynamics.com' }
        "europe" { 'https://admin.services.crm4.dynamics.com' }
        "asia" { 'https://admin.services.crm5.dynamics.com' }
        "australia" { 'https://admin.services.crm6.dynamics.com' }
        "japan" { 'https://admin.services.crm7.dynamics.com' }
        "india" { 'https://admin.services.crm8.dynamics.com' }
        "unitedkingdom" { 'https://admin.services.crm11.dynamics.com' }
        "france" { 'https://admin.services.crm12.dynamics.com' }
        default { $APIUrl }
       
    }

    return $result
}

function Get-PowerPlatformRegion {
    param(   
        [Parameter(Mandatory = $true)]
        [string]$CountryLetterCode
    )
    $result = switch ( $CountryLetterCode ) {
        "US" { 'unitedstates' }
        "AU" { 'australia' }
        "IN" { 'india' }
        "JP" { 'japan' }
        "CA" { 'canada' }
        "UK" { 'unitedkingdom' }
        "SA" { 'southamerica' }
        "FR" { 'france' }
        "UE" { 'unitedarabemirates' }
        "DE" { 'germany ' }
        "CH" { 'switzerland' }
        "NO" { 'norway' }
        "KR" { 'korea' }
        "ZA" { 'southafrica' }
        "AT" { 'europe' }
        "BE" { 'europe' }
        "DK" { 'europe' }
        "FI" { 'europe' }
        "GR" { 'europe' }
        "IT" { 'europe' }
        "PL" { 'europe' }
        "ES" { 'europe' }
        "SE" { 'europe' }

        "ID" { 'asia' }
        "MY" { 'asia' }
        "NZ" { 'asia' }
        "SA" { 'asia' }
        "TW" { 'asia' }
        
        default { '' }
       
    }
    return $result
}


function Remove-DataverseEnvironment {
    param(
        [Parameter(Mandatory = $false)]
        [string]$namePrefix = "Central Apps Test - "    
    )
  
    $searchPrefix = $namePrefix + '*'
    
    #delete all environment
    $envlist = Get-AdminPowerAppEnvironment | Where-Object { $_.DisplayName -like $searchPrefix }
    ForEach ($environment in $envlist) { 
        Remove-AdminPowerAppEnvironment -EnvironmentName $environment.EnvironmentName
    }
}
