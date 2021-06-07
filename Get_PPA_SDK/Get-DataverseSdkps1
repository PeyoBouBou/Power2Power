[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

#####################################################################################################
## FUNCTIONS
#####################################################################################################
function GetPlugin {
    <#
    .SYNOPSIS
        Download Plugin Registration Tool
    #>
    
    param (

    )

    Write-Host " - Download Plugin Registration Tool"
    ./nuget install Microsoft.CrmSdk.XrmTooling.PluginRegistrationTool -O .\Tools
    mkdir .\Tools\PluginRegistration
    $prtFolder = Get-ChildItem ./Tools | Where-Object {$_.Name -match 'Microsoft.CrmSdk.XrmTooling.PluginRegistrationTool.'}
    Move-Item $prtFolder\tools\*.* .\Tools\PluginRegistration
    Remove-Item $prtFolder -Force -Recurse    
}

function GetCore {
    <#
    .SYNOPSIS
        Download CoreTools
    #>
    
    param (
        
    )

    Write-Host " - Download CoreTools"
    ./nuget install  Microsoft.CrmSdk.CoreTools -O .\Tools
    mkdir .\Tools\CoreTools
    $coreToolsFolder = Get-ChildItem ./Tools | Where-Object {$_.Name -match 'Microsoft.CrmSdk.CoreTools.'}
    Move-Item $coreToolsFolder\content\bin\coretools\*.* .\Tools\CoreTools
    Remove-Item $coreToolsFolder -Force -Recurse    
}

function GetConfMig {
    <#
    .SYNOPSIS
        Download Configuration Migration
    #>
    
    param (
        
    )

    Write-Host " - Download Configuration Migration"
    ./nuget install  Microsoft.CrmSdk.XrmTooling.ConfigurationMigration.Wpf -O .\Tools
    mkdir .\Tools\ConfigurationMigration
    $configMigFolder = Get-ChildItem ./Tools | Where-Object {$_.Name -match 'Microsoft.CrmSdk.XrmTooling.ConfigurationMigration.Wpf.'}
    Move-Item $configMigFolder\tools\*.* .\Tools\ConfigurationMigration
    Remove-Item $configMigFolder -Force -Recurse
}

function GetPackDeploy {
    <#
    .SYNOPSIS
        Download Package Deployer 
    #>
    
    param (
        
    )

    Write-Host " - Download Package Deployer"
    ./nuget install  Microsoft.CrmSdk.XrmTooling.PackageDeployment.WPF -O .\Tools
    mkdir .\Tools\PackageDeployment
    $pdFolder = Get-ChildItem ./Tools | Where-Object {$_.Name -match 'Microsoft.CrmSdk.XrmTooling.PackageDeployment.Wpf.'}
    Move-Item $pdFolder\tools\*.* .\Tools\PackageDeployment
    Remove-Item $pdFolder -Force -Recurse
}

function GetMetaData {
    param (

    )
    ##
    ##Download Entity Metadata Browser 
    ##
    Write-Host " - Download Entity Metadata Browser"
    
    $MetadataBrowser3_5 = "http://download.microsoft.com/download/8/E/3/8E3279FE-7915-48FE-A68B-ACAFB86DA69C/MetadataBrowser_3_0_0_5_managed.zip"
    $MetadataBrowser3_4 = "http://download.microsoft.com/download/C/5/D/C5DEA99B-5CD1-40BA-BAB8-15CDC956FDAB/MetadataBrowser_3_0_0_4_managed.zip"
    $MetadataBrowser3_2 = "http://download.microsoft.com/download/6/D/3/6D341DDC-01B4-44A3-925D-D9188342E3B4/MetadataBrowser_3_0_0_2_managed.zip"
    

    mkdir .\Tools\EntityMetadataBrowser
    Invoke-WebRequest $MetadataBrowser3_5 -OutFile .\Tools\EntityMetadataBrowser\MetadataBrowser_3_0_0_5_managed.zip -Verbose
}

function GetXrmToolBox {
    <#
    .SYNOPSIS
        Download lastest'XrmToolbox.zip'
    #>

    param (
        
    )

    $sourceXrmToolbox = "https://github.com/MscrmTools/XrmToolBox/releases/latest"

    $xrmRawContent = Invoke-WebRequest $sourceXrmToolbox
    $xrmRawLine = $xrmRawContent.content -split '\n' | Select-String '/XrmToolbox.zip'
    $xrmSplitLine = $xrmRawLine -split '"'
    $xrmDownloadLine = 'https://github.com' + $xrmSplitLine[1]

    mkdir .\Tools\XrmToolbox
    Invoke-WebRequest $xrmDownloadLine -OutFile .\Tools\XrmToolbox\XrmToolbox.zip -Verbose  
}

#####################################################################################################
## MAIN
#####################################################################################################
Write-Host "START"

$varDate = Get-Date -Format "yyyyMMdd-HHmm"

#NuGet Param
$sourceNugetExe = "https://dist.nuget.org/win-x86-commandline/latest/nuget.exe"
$targetNugetExe = ".\nuget.exe"

if (Get-ChildItem -Filter Tools) {
    Write-Host " - Backup old Tools folder"
    Move-Item .\Tools .\Tools_$varDate
    #Remove-Item .\Tools -Force -Recurse -ErrorAction Ignore
}

Write-Host " - Get Nuget"
Invoke-WebRequest $sourceNugetExe -OutFile $targetNugetExe
Set-Alias nuget $targetNugetExe -Scope Global -Verbose

Write-Host " - Make Tools directory"
mkdir .\Tools        

## ACTIONS

 GetPlugin
 GetCore
 GetConfMig
 GetPackDeploy
 GetMetaData
 GetXrmToolBox

Write-Host " - Remove Nuget"
Remove-Item nuget.exe -Verbose

Write-Host "END"
