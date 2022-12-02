#  Run  Start-AppInADay-Setup 
#
#  V1.0 - 10/29/2019 - inital version
#  v1.1 - 11/30/2019 - changed default office license to E3
#  V1.2 - 01/22/2020 - changed default EnvSku to Trial on Reset / Resume
#  V1.3 - 01/23/2020 - Infer admin api url from region, add small delay after ad group create
#  V1.4 - 07/01/2020 - Allow run without creating CDS using -CreateCDS:$false
#  V1.5 - 05/31/2021 - Add E5 Trial in PowerApps Trial Env
####

   $LabAdminPrefix = "labuser";


   $LabAdminPassword = "test@word1"

   #For E3 use ENTERPRISEPACK
   #For E5 use ENTERPRISEPREMIUM
   #For E5 Trial in PowerApps Trial Env use SPE_E5
   $LabADminOfficeLicense="ENTERPRISEPACK"

   $LabAdminPowerLicense="POWERAPPS_PER_USER"

####
#   End of the configuraiton section
####

Install-Module -Name Microsoft.PowerApps.Administration.PowerShell -Scope CurrentUser -Force
Install-Module -Name Microsoft.PowerApps.PowerShell  -Scope CurrentUser -AllowClobber -Force

Install-Module Microsoft.Xrm.OnlineManagementAPI -Scope CurrentUser
Install-Module -Name Microsoft.Xrm.Data.Powershell -Scope CurrentUser

Install-Module -Name MSOnline -Scope CurrentUser -RequiredVersion 1.1.166.0 
Install-module azuread -Scope CurrentUser 

Import-Module Microsoft.PowerShell.Utility 

[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12;

Write-Host "### Prepare to run Start-AppInADay-Setup ###" 
Write-Host ""
Write-Host "  Start-AppInADay-Setup -TenantName 'MX60265ABC'  -CDSLocation 'unitedstates' -UserCount 10 "-ForegroundColor Green     
Write-Host "  Parameters details for Start-AppInADay-Setup:"
Write-Host "     TenantName : This is the name portion of name.onmicrosoft.com" -ForegroundColor Green  
Write-Host "     CDSLocation: This must match be appropriate for Region e.g. US = unitedstates"  -ForegroundColor Green
Write-Host "     UserCount: This is a number between 1 and 75 that is attending your event"  -ForegroundColor Green
Write-Host "     APIUrl : You can find the url for your tenant region here if not in US - https://docs.microsoft.com/en-us/dynamics365/customer-engagement/developer/online-management-api/get-started-online-management-api"  -ForegroundColor Green
Write-Host "     You can find out your tenant region by running running Get-MsolCompanyInformation and looking at CountryLetterCode" -ForegroundColor Green
Write-Host ""
Write-Host "### Ready for you to run Start-AppInADay-Setup ###" 

function Start-AppInADay-Setup
{
    <#
    .SYNOPSIS 
      Configure a tenant for running an App in a day workshop
    .EXAMPLE
     Start-AppInADay-Setup -TenantName 'MX60265ABC'  -CDSLocation 'unitedstates' -UserCount 10 
     
     TenantName : This is the name portion of name.onmicrosoft.com     
     CDSLocation: This must match be appropriate for Region e.g. US = unitedstates
     UserCount: This is a number between 1 and the max you have licenses for
     APIUrl : You can find the url for your region here if not in US - https://docs.microsoft.com/en-us/dynamics365/customer-engagement/developer/online-management-api/get-started-online-management-api
     Solution : This allows you to specify a CDS Solution that will be pre-loaded into each student environment
     EnvSKU: This can be either Trial or Production, default is Trial
     DeleteUsers: This will delete/disable all other uses besides the one that runs this script - use $true to enable - default is $false
    #>
    param(
    [Parameter(Mandatory = $true)]
    [string]$TenantName,
    [Parameter(Mandatory = $false)]
    [string]$CDSlocation="unitedstates",
    [Parameter(Mandatory = $true)]
    [int]$UserCount=1,
    [Parameter(Mandatory = $false)]
    [string]$APIUrl = "https://admin.services.crm.dynamics.com",
    [Parameter(Mandatory = $false)]
    [string]$Solution,
    [Parameter(Mandatory = $false)]
    [string]$EnvSKU="Trial",
    [Parameter(Mandatory = $false)]
    [switch]$DeleteUsers=$false,
      [Parameter(Mandatory = $false)]
    [switch]$CreateCDS=$true
    )

    Write-Host "Setup Starting"


    Write-Host "Tenant:" $TenantName
    $Tenant = $TenantName;
    Write-Host "Region:" $Region
    $TenantRegioin = $Region;
    Write-Host "API Url:" $APIUrl
    $AdminAPIUrl = Get-AdminServiceUrl -CDSlocation $CDSlocation  -APIUrl $APIUrl
    Write-Host "CDS Location:" $CDSlocation
    Write-Host "User Count:" $UserCount
    $LabAdminCount = $UserCount
    

    $DomainName =$Tenant + ".onmicrosoft.com"

    $UserCredential = Get-Credential

    Write-Host "Connecting to Office 365..."
    Connect-MsolService -Credential $UserCredential
    Write-Host "Connecting to Azure AD..."
    Connect-AzureAD -Credential $UserCredential
    Write-Host "Connecting to PowerApps..."
    try{
       Add-PowerAppsAccount -Username $UserCredential.UserName -Password $UserCredential.Password
    }
    catch { 
       Write-Host "Error connecting to PowerApps, if error includes Cannot find overload for UserCredential please run CleanupOldModules.ps1 and retry this script"
       Read-Host -Prompt 'Press <Enter> to exit, then restart script with proper information'
       exit
    }
    

    

    if ($DeleteUsers -eq $true) {
        $confirmDelete = Read-Host -Prompt 'Confirm disabling all accounts other than this admin account(Y/N)'
        if ($confirmDelete -and $confirmDelete -eq 'Y') {
	        Write-Host "Proceeding to disable all users"
            Delete-DemoUsers;
        }
    }
        
    $companyInfo = Get-MsolCompanyInformation   

    $verifyLicense = Verify-Licenses -Tenant $Tenant -UserCount $LabAdminCount
    
    if ($verifyLicense -eq $true)
    {     
        
        Create-LabAdminUsers -Tenant $Tenant -Count $LabAdminCount -TenantRegion $companyInfo.CountryLetterCode -password $LabAdminPassword -userprefix $LabAdminPrefix    

        Setup-AddLabAdminToGroup

        Add-PowerAppsAccount -Username $UserCredential.UserName -Password $UserCredential.Password
       

        if ($CreateCDS -eq $true) {

            Create-CDSenvironment -namePrefix "Dev - " -CDSlocation $CDSlocation -password $LabAdminPassword -EnvSKU $EnvSKU        

            Wait-ForEnvProvisioning -namePrefix "Dev - " -envCount $UserCount

            Create-CDSDatabases -namePrefix "Dev - "

            if ($EnvSKU -ne "Trial")
            {
                Setup-AddLabAdminToSysAdmin-StudentEnvs -namePrefix "Dev - "     
            }

            Install-SolutionFile-ToEnv -nameprefix "Dev - " -solution $Solution -APIUrl $AdminAPIUrl
        }

        
     }
     else
     {
        Write-Host "Your current licensed skus are:"
        Get-MsolAccountSku | Format-Table -Property AccountSkuID
        Write-Host "Fix your licenses and then restart"
     }
        

    Write-Host "Setup Ending"
}

function Reset-AppInADay
{
   <#
    .SYNOPSIS 
      This will delete all existing student environments and then create new ones
    .EXAMPLE
     Reset-AppInADay -TenantName 'MX60265ABC'  -CDSLocation 'unitedstates'  'https://admin.services.crm.dynamics.com'
     
     TenantName : This is the name portion of name.onmicrosoft.com     
     CDSLocation: This must match be appropriate for Region e.g. US = unitedstates     
     APIUrl : You can find the url for your region here if not in US - https://docs.microsoft.com/en-us/dynamics365/customer-engagement/developer/online-management-api/get-started-online-management-api
     Solution : This allows you to specify a CDS Solution that will be pre-loaded into each student environment
     EnvSKU: This can be either Trial or Production, default is Trial     
    #>
param(
    [Parameter(Mandatory = $true)]
    [string]$TenantName,
    [Parameter(Mandatory = $false)]
    [string]$CDSlocation="unitedstates",   
       [Parameter(Mandatory = $false)]
    [string]$APIUrl = "https://admin.services.crm.dynamics.com",
    [Parameter(Mandatory = $false)]
    [string]$Solution,
     [Parameter(Mandatory = $false)]
    [string]$EnvSKU="Trial"
    )

    Write-Host "Reset Starting"


    Write-Host "Tenant:" $TenantName
    $Tenant = $TenantName;
    Write-Host "Region:" $Region
    $TenantRegioin = $Region;
    Write-Host "API Url:" $APIUrl
    $AdminAPIUrl = Get-AdminServiceUrl -CDSlocation $CDSlocation  -APIUrl $APIUrl
    Write-Host "CDS Location:" $CDSlocation

    
    $DomainName =$Tenant + ".onmicrosoft.com"

    $UserCredential = Get-Credential

    Write-Host "Connecting to Office 365..."
    Connect-MsolService -Credential $UserCredential
    Write-Host "Connecting to Azure AD..."
    Connect-AzureAD -Credential $UserCredential
    Write-Host "Connecting to PowerApps..."
    try{
    Add-PowerAppsAccount -Username $UserCredential.UserName -Password $UserCredential.Password
    }
    catch { 
       Write-Host "Error connecting to PowerApps, if error includes Cannot find overload for UserCredential please run CleanupOldModules.ps1 and retry this script"
       Read-Host -Prompt 'Press <Enter> to exit, then restart script with proper information'
       exit
    }
    
        
        $companyInfo = Get-MsolCompanyInformation        
                            

        Add-PowerAppsAccount -Username $UserCredential.UserName -Password $UserCredential.Password

        Delete-CDSenvironment -namePrefix "Dev - "

        Wait-ForCDSDeleting -namePrefix "Dev - "
        
        Create-CDSenvironment -namePrefix "Dev - " -CDSlocation $CDSlocation -password $LabAdminPassword -EnvSKU $EnvSKU

        Add-PowerAppsAccount -Username $UserCredential.UserName -Password $UserCredential.Password
        
        Create-CDSDatabases -namePrefix "Dev - "

        
        if ($EnvSKU -ne "Trial")
        {
            Setup-AddLabAdminToSysAdmin-StudentEnvs -namePrefix "Dev - "     
        }

        Install-SolutionFile-ToEnv -nameprefix "Dev - " -solution $Solution -APIUrl $AdminAPIUrl
          

    Write-Host "Setup Ending"
}

function Cleanup-AppInADay
{
  <#
    .SYNOPSIS 
      This will delete all existing student environments 
    .EXAMPLE
     Cleanup-AppInADay -TenantName 'MX60265ABC'   'https://admin.services.crm.dynamics.com'
     
     TenantName : This is the name portion of name.onmicrosoft.com     
     APIUrl : You can find the url for your region here if not in US - https://docs.microsoft.com/en-us/dynamics365/customer-engagement/developer/online-management-api/get-started-online-management-api
    #>
param(
    [Parameter(Mandatory = $true)]
    [string]$TenantName,  
    [Parameter(Mandatory = $false)]
    [string]$APIUrl = "https://admin.services.crm.dynamics.com"
    )

    Write-Host "cleanup Starting"


    Write-Host "Tenant:" $TenantName
    $Tenant = $TenantName;
    Write-Host "Region:" $Region
    $TenantRegioin = $Region;
    Write-Host "API Url:" $APIUrl
    $AdminAPIUrl = Get-AdminServiceUrl -CDSlocation $CDSlocation  -APIUrl $APIUrl
    Write-Host "CDS Location:" $CDSlocation

    
    $DomainName =$Tenant + ".onmicrosoft.com"

    $UserCredential = Get-Credential

    Write-Host "Connecting to Office 365..."
    Connect-MsolService -Credential $UserCredential
    Write-Host "Connecting to Azure AD..."
    Connect-AzureAD -Credential $UserCredential
    Write-Host "Connecting to PowerApps..."
    try{
    Add-PowerAppsAccount -Username $UserCredential.UserName -Password $UserCredential.Password
    }
    catch { 
       Write-Host "Error connecting to PowerApps, if error includes Cannot find overload for UserCredential please run CleanupOldModules.ps1 and retry this script"
       Read-Host -Prompt 'Press <Enter> to exit, then restart script with proper information'
       exit
    }
    
        
        $companyInfo = Get-MsolCompanyInformation                                    

        Add-PowerAppsAccount -Username $UserCredential.UserName -Password $UserCredential.Password

        Delete-CDSenvironment -namePrefix "Dev - "
                
        Wait-ForCDSDeleting -namePrefix "Dev - "

    Write-Host "Cleanup Ending"
}

function Resume-AppInADay-CDSProvisioning
{
  <#
    .SYNOPSIS 
      This will resume provisioning student environments in case the inital script has to be restarted
    .EXAMPLE
     Resume-AppInADay-CDSProvisioning -TenantName 'MX60265ABC'  -CDSLocation 'unitedstates'  'https://admin.services.crm.dynamics.com'
     
     TenantName : This is the name portion of name.onmicrosoft.com     
     CDSLocation: This must match be appropriate for Region e.g. US = unitedstates     
     APIUrl : You can find the url for your region here if not in US - https://docs.microsoft.com/en-us/dynamics365/customer-engagement/developer/online-management-api/get-started-online-management-api
     Solution : This allows you to specify a CDS Solution that will be pre-loaded into each student environment
     EnvSKU: This can be either Trial or Production, default is Trial     
    #>
param(
    [Parameter(Mandatory = $true)]
    [string]$TenantName,
    [Parameter(Mandatory = $false)]
    [string]$CDSlocation="unitedstates",   
       [Parameter(Mandatory = $false)]
    [string]$APIUrl = "https://admin.services.crm.dynamics.com",
     [Parameter(Mandatory = $false)]
    [string]$Solution,
     [Parameter(Mandatory = $false)]
    [string]$EnvSKU="Trial"
    )
    Write-Host "Resume Starting"

     Write-Host "Tenant:" $TenantName
    $Tenant = $TenantName;
    Write-Host "Region:" $Region
    $TenantRegioin = $Region;
    Write-Host "API Url:" $APIUrl
    $AdminAPIUrl = Get-AdminServiceUrl -CDSlocation $CDSlocation  -APIUrl $APIUrl
    Write-Host "Admin Url:" $AdminAPIUrl
    Write-Host "CDS Location:" $CDSlocation

    $DomainName =$Tenant + ".onmicrosoft.com"

    $UserCredential = Get-Credential

    Write-Host "Connecting to Office 365..."
    Connect-MsolService -Credential $UserCredential
    Write-Host "Connecting to Azure AD..."
    Connect-AzureAD -Credential $UserCredential
    Write-Host "Connecting to PowerApps..."
    try{
    Add-PowerAppsAccount -Username $UserCredential.UserName -Password $UserCredential.Password
    }
    catch { 
       Write-Host "Error connecting to PowerApps, if error includes Cannot find overload for UserCredential please run CleanupOldModules.ps1 and retry this script"
       Read-Host -Prompt 'Press <Enter> to exit, then restart script with proper information'
       exit
    }
    
        
        $companyInfo = Get-MsolCompanyInformation                                    

        Add-PowerAppsAccount -Username $UserCredential.UserName -Password $UserCredential.Password

        Create-CDSenvironment -namePrefix "Dev - " -CDSlocation $CDSlocation -password $LabAdminPassword -EnvSKU $EnvSKU

        Add-PowerAppsAccount -Username $UserCredential.UserName -Password $UserCredential.Password
        
        Create-CDSDatabases -namePrefix "Dev - "

         if ($EnvSKU -ne "Trial")
        {
            Setup-AddLabAdminToSysAdmin-StudentEnvs -namePrefix "Dev - "     
        }

        Install-SolutionFile-ToEnv -nameprefix "Dev - " -solution $Solution -APIUrl $AdminAPIUrl
         

    Write-Host "Setup Ending"
}

function Verify-Licenses
{
  param(  
  [Parameter(Mandatory = $true)]
    [string]$Tenant,  
    [Parameter(Mandatory = $true)]
    [int]$UserCount=1    
    )
    
    $licensesGood = $true

    $skus = Get-MsolAccountSku
    $skuquery = $Tenant+":"+$LabAdminPowerLicense
    $sku = $skus.where({$_.AccountSkuId -eq $skuquery}) 
    if ($sku -eq $null -or $sku.Count -eq 0)
    {
        Write-Host "No License in tenant for LabAdminPowerLicense " $LabAdminPowerLicense " Add license or change sku before you continue" -ForegroundColor red
        $licensesGood = $false
    }
    $skuquery = $Tenant+":"+$LabAdminOfficeLicense
    $sku = $skus.where({$_.AccountSkuId -eq $skuquery}) 
    if ($sku -eq $null -or $sku.Count -eq 0)
    {
        Write-Host "No License in tenant for LabAdminOfficeLicense " $LabAdminOfficeLicense " Add license or change sku before you continue" -ForegroundColor red
        $licensesGood = $false
    }

    return $licensesGood
}

function Delete-DemoUsers 
{

    Write-Host "***Removing Demo Users ****" -ForegroundColor Green

    Get-MsolUser | where {$_.UserPrincipalName -notlike $userCredential.UserName}|Remove-MsolUser -Force

    Write-Host "****Old Users Deleted ****" -ForegroundColor Green
    Get-MsolUser |fl displayname,licenses

}

function Create-LabAdminUsers
{
   param
    (
    [Parameter(Mandatory = $true)]
    [string]$Tenant,
    [Parameter(Mandatory = $true)]
    [int]$Count,
    [Parameter(Mandatory = $false)]
    [string]$TenantRegion="GB",
    [Parameter(Mandatory = $false)]
    [string]$password=$UserPassword,
     [Parameter(Mandatory = $false)]
    [string]$userprefix="labadmin",
    [Parameter(Mandatory = $false)]
    [int]$startCount=1,
     [Parameter(Mandatory = $false)]
    [string]$powerLicense=$LabAdminPowerLicense
    
    )

    $DomainName = $Tenant+".onmicrosoft.com"


    
    Write-Host "Tenant: " $Tenant
    Write-Host "Domain Name: " $DomainName
    Write-Host "Count: " $Count
    Write-Host "Licence Plans: " (Get-MsolAccountSku).AccountSkuId
    Write-Host "TenantRegion: " $TenantRegion
    Write-Host "CDSlocation: " $CDSlocation
    Write-Host "password: " $password

  
    $securepassword = ConvertTo-SecureString -String $password -AsPlainText -Force
    
 
       Write-Host "creating users " -ForegroundColor Green
   
       for ($i=$startCount;$i -lt $Count+1; $i++) {
       


        $firstname = "Lab"
        $lastname = "Admin" + $i
        $displayname = "Lab Admin " + $i
        $email = ($userprefix + $i + "@" + $DomainName).ToLower()
        $existingUser = Get-MsolUser -UserPrincipalName $email -ErrorAction SilentlyContinue

        if($existingUser -eq $Null)
        {
         
         New-MsolUser -DisplayName $displayname -FirstName $firstname -LastName $lastname -UserPrincipalName $email -UsageLocation $TenantRegion -Password $password -LicenseAssignment $Tenant":"$powerLicense -PasswordNeverExpires $true -ForceChangePassword $false  
         
         if ($LabADminOfficeLicense -ne $null -and $LabADminOfficeLicense -ne "")
         {
            Set-MsolUserLicense -UserPrincipalName $email -AddLicenses $Tenant":"$LabADminOfficeLicense
         }
         
            #For E3 Set-MsolUserLicense -UserPrincipalName $email -AddLicenses $Tenant":ENTERPRISEPACK" -Verbose
            #For E5 Set-MsolUserLicense -UserPrincipalName $email -AddLicenses $Tenant":ENTERPRISEPREMIUM" -Verbose
        }
         
        }
        Write-Host "*****************Lab Users Created ***************" -ForegroundColor Green
        $userQuery = $LabAdminPrefix+'*'
        Get-MsolUser | where {$_.UserPrincipalName -like $userQuery}|fl displayname,licenses

}

function Setup-AddLabAdminToGroup
{

    Write-Host "Starting add labadmin users to Lab Admin Team group"

   $userprefix =$LabAdminPrefix+'*'

   $adminGroup = Get-azureADGroup | where {$_.DisplayName -eq "Lab Admin Team"} | Select-Object -first 1

   if (!$adminGroup)
   {
        $adminGroup = New-AzureADGroup -Description "Lab Admin Team" -DisplayName "Lab Admin Team" -MailEnabled $false -SecurityEnabled $true -MailNickName "LabAdmins"
        Write-Host "Created new group " $adminGroup.ObjectId
        write-host "Short delay to allow group creation to finish..."
        Start-Sleep -s 15
   }
   else
   {
        Write-Host "Found existing group " $adminGroup.ObjectId
   }
   
   $users = Get-MsolUser | where {$_.UserPrincipalName -like $userprefix} | Sort-Object UserPrincipalName

   $existingMembers = Get-AzureADGroupMember -ObjectId $adminGroup.ObjectId | Select -ExpandProperty UserPrincipalName


    ForEach ($user in $users) { 

        if (!$existingMembers -contains $user.UserPrincipalName)
        {

            write-host "adding user "  $user.UserPrincipalName  " to group "  $adminGroup.DisplayName

            Add-AzureADGroupMember -ObjectId $adminGroup.ObjectId -RefObjectId $user.ObjectId
        }
        else
        {
            write-host "user "  $user.UserPrincipalName  " is already a member of "  $adminGroup.DisplayName
        }

        
    }
    Write-Host "Ending add labadmin users to Lab Admin Team group"
}

function Install-SolutionFile-ToEnv
{
 param(
    [Parameter(Mandatory = $true)]
    [string]$namePrefix="Central Apps Test - ",
    [Parameter(Mandatory = $false)]
    [string]$solution,
    [Parameter(Mandatory = $false)]
    [string]$APIUrl = "https://admin.services.crm.dynamics.com"   
    )


    Write-Host "Starting import of starting solution"
    
    if ($solution -ne "" -and $solution -ne $null)
    {
   
        $cdsInstances = Get-CrmInstances -ApiUrl $APIUrl -Credential $UserCredential 

        $envQuery = '*'+$namePrefix+'*'
        $envlist=$cdsInstances.Where({$_.EnvironmentType  -ne 'Default'}).Where({$_.FriendlyName -like  $envQuery })

        Write-Host "Found " $envlist.Count " environments to process"

        ForEach ($environemnt in $envlist) { 
     
             Write-Host "Processing environment :" $environemnt.FriendlyName


             $conn = Connect-CrmOnline -Credential $UserCredential -ServerUrl $environemnt.ApplicationUrl
             
    
            $solutionPath = $PSScriptRoot + "\" + $solution

            Write-Host "Importing " $solutionPath

            try{

                Import-CrmSolution -conn $conn -SolutionFilePath $solutionPath -PublishChanges $true
            }
            Catch
            {
                $ErrorMessage = $_.Exception.Message        
                if ($ErrorMessage -like '*timeout*' -or $ErrorMessage -like '*Underlying connection was closed*' )
                { 
                    write-host "  retrying import due to timeout after short delay"
                    Start-Sleep -s 30
                    Import-CrmSolution -conn $conn -SolutionFilePath $solutionPath -Verbose -PublishChanges $true
                }
                else
                {
                    write-host $ErrorMessage -ForegroundColor Red
                }
                
        
            }
    
         }   
     }
     
   
     Write-Host "Ending import of starting solution"
}

function Verify-SolutionFile-ToEnv
{
 param(
    [Parameter(Mandatory = $true)]
    [string]$namePrefix="Central Apps Test - ",
    [Parameter(Mandatory = $false)]    
    [string]$uniquename,
    [Parameter(Mandatory = $false)]
    [string]$APIUrl = "https://admin.services.crm.dynamics.com"   
    )


    Write-Host "Starting verify solution"
    
    
   
    $cdsInstances = Get-CrmInstances -ApiUrl $APIUrl -Credential $UserCredential 

    $envQuery = '*'+$namePrefix+'*'
    $envlist=$cdsInstances.Where({$_.EnvironmentType  -ne 'Default'}).Where({$_.FriendlyName -like  $envQuery })

    Write-Host "Found " $envlist.Count " environments to process"

    ForEach ($environemnt in $envlist) { 
     
            Write-Host "Processing environment :" $environemnt.FriendlyName


        $conn = Connect-CrmOnline -Credential $UserCredential -ServerUrl $environemnt.ApplicationUrl
                                      

        $solutionList = Get-CrmRecords `
            -EntityLogicalName solution `
            -Fields uniquename `
            -conn $conn

        $sol = $solutionList.CrmRecords.Where({$_.uniquename -eq $uniquename})
        if ($sol.Count -eq 1)
        {
            Write-Host "   Solution verified" -ForegroundColor Green
        }
        else
        {
            Write-Host "   Solution Not Found:" $environemnt.FriendlyName -ForegroundColor Red
        }
    
        }   
    
     
   
     Write-Host "Ending import of starting solution"
}

function Create-CDSenvironment 
{

    param(
    [Parameter(Mandatory = $true)]
    [string]$namePrefix="Central Apps Test - ",
    [Parameter(Mandatory = $false)]
    [string]$password=$UserPassword,
    [Parameter(Mandatory = $false)]
    [string]$CDSlocation="canada",
    [Parameter(Mandatory = $false)]
    [string]$EnvSKU="Trial"
    )

    $userprefix = $LabAdminPrefix + '*'

    $starttime= Get-Date -DisplayHint Time
    Write-Host " Starting CreateCDSEnvironment :" $starttime   -ForegroundColor Green

    $securepassword = ConvertTo-SecureString -String $password -AsPlainText -Force
    $users = Get-MsolUser | where {$_.UserPrincipalName -like $userprefix } | Sort-Object UserPrincipalName

    $allEnvList = @(Get-AdminPowerAppEnvironment)
    
    ForEach ($user in $users) { 
        $envDev=$null
        $envProd=$null

        if ($user.isLicensed -eq $false)
        {
            write-host " skiping user " $user.UserPrincipalName " he is not licensed" -ForegroundColor Red
            continue
        }

        if ($EnvSKU -eq "Trial")
        {
            write-host " switching to user " $user.UserPrincipalName 

            Add-PowerAppsAccount -Username $user.UserPrincipalName -Password $securepassword -Verbose
        }

        write-host " creating environment for user " $user.UserPrincipalName 
         
         $envDisplayname = $namePrefix + $user.UserPrincipalName.Split('@')[0] 
         $envDisplayname

         $envQuery = $envDisplayname + "*"
         
         $envDevList = @($allEnvList.where( { $_.DisplayName -like $envQuery }))         
        
        if ($envDevList.count -eq 0 ) { 
       
            $envDev = New-AdminPowerAppEnvironment -DisplayName  $envDisplayname -LocationName $CDSlocation -EnvironmentSku $EnvSKU -Verbose 
            
       
            Write-Host " Created CDS Environment with id :" $envDev.DisplayName   -ForegroundColor Green 
        }
        else{
            Write-Host " Skipping CDS Environment with id :" $envDev.DisplayName " it already exists"  -ForegroundColor Green 
        }
             
         
    }
    if ($EnvSKU -eq "Trial")
    {
        write-host " switching back to user " $UserCredential.UserName 

        Add-PowerAppsAccount -Username $UserCredential.UserName -Password $UserCredential.Password
    }
    $endtime = Get-Date -DisplayHint Time
    $duration = $("{0:hh\:mm\:ss}" -f ($endtime-$starttime))
    Write-Host "End of CreateCDSEnvironment at : " $endtime "  Duration: " $duration   -ForegroundColor Green

}

function Create-CDSDatabases 
{
 param(
    [Parameter(Mandatory = $true)]
    [string]$namePrefix="Central Apps"
    )

        $searchPrefix = '*' + $namePrefix + '*'

        $starttime= Get-Date -DisplayHint Time
        Write-Host "Starting CreateCDSDatabases :" $starttime   -ForegroundColor Green

        $CDSenvs = Get-AdminPowerAppEnvironment | where { $_.DisplayName -like $searchPrefix -and $_.commonDataServiceDatabaseType -eq "none"} | Sort-Object displayname
              
        
        Write-Host "creating CDS databases for following environments :
          " $CDSenvs.DisplayName "
        ****************************************************************
        ****************************************************************" -ForegroundColor Green

        ForEach ($CDSenv in $CDSenvs) { 
         $CDSenv.EnvironmentName
         Write-Host "creating CDS databases for:" $CDSenv.DisplayName " id:" $CDSenv.EnvironmentName -ForegroundColor Yellow
           
             New-AdminPowerAppCdsDatabase -EnvironmentName  $CDSenv.EnvironmentName -CurrencyName USD -LanguageName 1033  -ErrorAction Continue -WaitUntilFinished $false   -Templates @(“D365_CDSSampleApp“)
           
        }

        Wait-ForCDSProvisioning -namePrefix $namePrefix


        $endtime = Get-Date -DisplayHint Time
        $duration = $("{0:hh\:mm\:ss}" -f ($endtime-$starttime))
        Write-Host "End of CreateCDSDatabases at : " $endtime "  Duration: " $duration   -ForegroundColor Green
        
}

function Wait-ForEnvProvisioning
{

param(
    [Parameter(Mandatory = $true)]
    [string]$namePrefix="Central Apps",
    [Parameter(Mandatory = $true)]
    [int]$envCount
    )

        $searchPrefix = '*' + $namePrefix + '*'

        Write-host "Checking on provisioning status of environments"
        Do  
        {
            
            $CDSenvs = @(Get-AdminPowerAppEnvironment | where { $_.DisplayName -like $searchPrefix  })         
            
            
            if ($CDSenvs.count -ne $envCount)
            {
                Write-Host "There are" $CDSenvs.count "environments of $envCount - Waiting 30 seconds "
                Start-Sleep -s 30
            }
        } While ($CDSenvs.count -ne $envCount)
}

function Wait-ForCDSProvisioning
{

param(
    [Parameter(Mandatory = $true)]
    [string]$namePrefix="Central Apps"
    )

        $searchPrefix = '*' + $namePrefix + '*'

        Write-host "Checking on provisioning status of CDS"
        Do  
        {
            
            $CDSenvs = @(Get-AdminPowerAppEnvironment | where { $_.DisplayName -like $searchPrefix -and $_.CommonDataServiceDatabaseProvisioningState -ne "Succeeded" })         
            
            
            if ($CDSenvs.count -gt 0)
            {
                Write-Host "There are" $CDSenvs.count "CDS provisionings left - Waiting 30 seconds "
                Start-Sleep -s 30
            }
        } While ($CDSenvs.count -gt 0)
}

function Wait-ForCDSDeleting
{

param(
    [Parameter(Mandatory = $true)]
    [string]$namePrefix="Central Apps"
    )

        $searchPrefix = '*' + $namePrefix + '*'

        Write-host "Checking on delete status of CDS"
        Do  
        {
            
            $CDSenvs = @(Get-AdminPowerAppEnvironment | where { $_.DisplayName -like $searchPrefix  })         
            
            
            if ($CDSenvs.count -gt 0)
            {
                Write-Host "There are" $CDSenvs.count "CDS removals left - Waiting 30 seconds "
                Start-Sleep -s 30
            }
        } While ($CDSenvs.count -gt 0)
}

function Setup-AddLabAdminToSysAdmin-StudentEnvs
{

    param(
    [Parameter(Mandatory = $true)]
    [string]$namePrefix="Central Apps Test - "
    )

    Write-Host "Starting add lab admin to test environment as sysadmin"

    $role = 'System Administrator'

    $cdsInstances = Get-CrmInstances -ApiUrl $AdminAPIUrl -Credential $UserCredential 

    $searchPrefix = '*' + $namePrefix + '*'

    $envlist=$cdsInstances.Where({$_.EnvironmentType  -ne 'Default'}).Where({$_.FriendlyName -like $searchPrefix })

    Write-Host "Found " $envlist.count " environments to process"

        ForEach ($environemnt in $envlist) { 
     
         Write-Host "Processing environment :" $environemnt.FriendlyName


         $conn = Connect-CrmOnline -Credential $UserCredential -ServerUrl $environemnt.ApplicationUrl

#        $conn.IsReady,$conn.ConnectedOrgFriendlyName
    
   
        $users = Get-CrmRecords `
               -EntityLogicalName systemuser `
               -Fields domainname,systemuserid, fullname `
               -conn $conn
              
        $compareString =$conn.ConnectedOrgFriendlyName -replace $namePrefix,"*" 
        $compareString = $compareString +  "@*"
        Write-Host "comparing("$compareString")"

     $selectedUsers = $users.CrmRecords | where { $_.domainname -like $compareString} | Sort-Object domainname

        Write-Host "Found "$selectedUsers.count " users to process"

        ForEach ($user in $selectedUsers) { 

            write-host "  adding user "$user.fullname" to group sysadmin"

            try
            {
                Add-CrmSecurityRoleToUser `
                   -UserId $user.systemuserid `
                   -SecurityRoleName $role `
                   -conn $conn

                write-host "  added user "  $user.fullname  " to group sysadmin"

             }
            Catch
            {
                $ErrorMessage = $_.Exception.Message        
                if ($ErrorMessage -like '*Cannot insert duplicate key*')
                { 
                    write-host "  Skipping user "  $user.fullname  " already a member"
                }
                else
                {
                    write-host $ErrorMessage -ForegroundColor Red
                }
                
        
            }
        
         } #foreach user

    
     }   #foreach env
     Write-Host "Ending add lab admin to test environment as sysadmin"
}

function Get-AdminServiceUrl
{
param(   
    [Parameter(Mandatory = $false)]
    [string]$CDSlocation="unitedstates",
    [Parameter(Mandatory = $false)]
    [string]$APIUrl="https://admin.services.crm.dynamics.com"
    )
   $result = switch ( $CDSlocation )
    {
        "unitedstates" { 'https://admin.services.crm.dynamics.com'    }
        "southamerica" { 'https://admin.services.crm2.dynamics.com'    }
        "canada" { 'https://admin.services.crm3.dynamics.com'    }
        "europe" { 'https://admin.services.crm4.dynamics.com'    }
        "asia" { 'https://admin.services.crm5.dynamics.com'    }
        "australia" { 'https://admin.services.crm6.dynamics.com'    }
        "japan" { 'https://admin.services.crm7.dynamics.com'    }
        "india" { 'https://admin.services.crm8.dynamics.com'    }
        "unitedkingdom" { 'https://admin.services.crm11.dynamics.com'    }
        "france" { 'https://admin.services.crm12.dynamics.com'    }
        default { $APIUrl    }
       
    }

    return $result
}

function Delete-CDSenvironment
{
param(
    [Parameter(Mandatory = $true)]
    [string]$namePrefix="Central Apps Test - "    
    )
  
    $searchPrefix =  $namePrefix + '*'
    
    #delete all environemnt
    $envlist=Get-AdminPowerAppEnvironment | where {$_.DisplayName -like $searchPrefix}
    ForEach ($environemnt in $envlist) { 
     Remove-AdminPowerAppEnvironment -EnvironmentName $environemnt.EnvironmentName
    }
}