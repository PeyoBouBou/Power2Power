clear;

function Add-Crm-Sdk
{
	# Load SDK assemblies
	Add-Type -Path "$PSScriptRoot\Assemblies\Microsoft.Xrm.Sdk.dll";
	Add-Type -Path "$PSScriptRoot\Assemblies\Microsoft.Xrm.Client.dll";
	Add-Type -Path "$PSScriptRoot\Assemblies\Microsoft.Crm.Sdk.Proxy.dll";
}

function Add-Tfs-Sdk
{
    # Load TFS SDK assemblies
    [void][System.Reflection.Assembly]::LoadWithPartialName("Microsoft.TeamFoundation");
    [void][System.Reflection.Assembly]::LoadWithPartialName("Microsoft.TeamFoundation.Common");
    [void][System.Reflection.Assembly]::LoadWithPartialName("Microsoft.TeamFoundation.Client");
    [void][System.Reflection.Assembly]::LoadWithPartialName("Microsoft.TeamFoundation.VersionControl.Client");
    [void][System.Reflection.Assembly]::LoadWithPartialName("Microsoft.TeamFoundation.VersionControl.Common");
}

$logName = "MCS.Scripts";
$logSource = "CrmToTfs";

function Create-Log()
{
    $logFileExists = Get-EventLog -list | Where-Object {$_.Log -eq $logName } 
    if (!$logFileExists) 
    {
        New-EventLog -LogName $logName -Source $logSource;
    }
}

function Log-Error($message)
{
    Write-EventLog -LogName $logName -Source $logSource -EntryType Error -Message $message -EventId 0;
}

function Log-Info($message)
{
    Write-EventLog -LogName $logName -Source $logSource -EntryType Information -Message $message -EventId 0;
}

function Get-Configuration()
{
	$configFilePath = "$PSScriptRoot\Configuration.xml";
    $content = Get-Content $configFilePath;
	return [xml]$content;
}

Create-Log;
Add-Tfs-Sdk;
Add-Crm-Sdk;
$config = Get-Configuration;

foreach($syncItem in $config.Configuration.SyncItems.SyncItem)
{
    $d = Get-Date;
    $syncItemName = $syncItem.Name;
    $workspacePath = $syncItem.Tfs.WorkSpaceFolder;
    Write-Host "$d - Crm To Tfs synchronization start for '$syncItemName'" -ForegroundColor Cyan;


    # =======================================================
    # TFS Connection
    # =======================================================
    $d = Get-Date;
    Write-Host "  > $d : Checking TFS connection ..." -NoNewline;
    $tfsUrl = $syncItem.Tfs.CollectionUrl;
    $tfsCollection = [Microsoft.TeamFoundation.Client.TfsTeamProjectCollectionFactory]::GetTeamProjectCollection($tfsUrl);
    $tfsCollection.EnsureAuthenticated();
    if($tfsCollection.HasAuthenticated)
    {
        Write-Host "Authenticated to TFS!" -ForegroundColor Green;
        Log-Info "Checking TFS connection ... Authenticated to TFS!";
    }
    else
    {
        Write-Host "Not authenticated to TFS ..." -ForegroundColor Red;
        Log-Error "Checking TFS connection ... Not authenticated to TFS";
        return;
    }

    # =======================================================
    # Crm Connection
    # =======================================================
    $crmConnectionString = $syncItem.Crm.ConnectionString;
	$crmConnection = [Microsoft.Xrm.Client.CrmConnection]::Parse($crmConnectionString);
    $service = New-Object -TypeName Microsoft.Xrm.Client.Services.OrganizationService -ArgumentList $crmConnection;

    # =======================================================
    # Publish
    # =======================================================
    $d = Get-Date;
    Write-Host "  > $d : Publishing customizations ..." -NoNewline;
    $publishRequest = New-Object -TypeName Microsoft.Crm.Sdk.Messages.PublishAllXmlRequest;
    try
    {
        $publishResponse = $service.Execute($publishRequest);
        Write-Host "done!" -ForegroundColor Green;
        Log-Info "Publishing customizations ... done!";
    }
    catch [Exception]
    {
        Write-Host "failed! [Error : $_.Exception]" -ForegroundColor Red;
        Log-Error "Publishing customizations ... failed![Error : $_.Exception]";
        return;
    }  

    
    $outputPath = $syncItem.OutputPath;
    $syncItemPath = [System.IO.Path]::Combine($outputPath, $syncItem.Name);
   
    New-Item -ErrorAction Ignore -ItemType directory -Path $syncItemPath;

    foreach($solution in $syncItem.Crm.Solutions.Solution)
    {
        # =======================================================
        # Export solution
        # =======================================================
    
        $solutionToExport = $solution.Name;
        $solutionPath = [System.IO.Path]::Combine($syncItemPath, "$solutionToExport.zip");

        $d = Get-Date;
        Write-Host "  > $d : Exporting solution ($solutionToExport) to path '$solutionPath' ... " -NoNewline;
        $request = New-Object -TypeName Microsoft.Crm.Sdk.Messages.ExportSolutionRequest;
        $request.SolutionName = $solutionToExport;
        $request.Managed = $false;    
        $request.ExportCalendarSettings = $true;
        $request.ExportCustomizationSettings = $true;
        $request.ExportEmailTrackingSettings = $true;
        $request.ExportAutoNumberingSettings = $true;
        $request.ExportIsvConfig = $true;
        $request.ExportOutlookSynchronizationSettings = $true;
        $request.ExportGeneralSettings = $true;
        $request.ExportMarketingSettings = $true;
        $request.ExportRelationshipRoles = $true;
        try
        {
            $response = $service.Execute($request);
            [System.IO.File]::WriteAllBytes($solutionPath, $response.ExportSolutionFile);
            Write-Host "done!" -ForegroundColor Green;
            Log-Info "Exporting solution ... done!";
        }
        catch [Exception]
        {
            Write-Host "failed! [Error : $_.Exception]" -ForegroundColor Red;
            Log-Error "Exporting solution ... failed! [Error : $_.Exception]";
            return;
        }            

        # =======================================================
        # Unpack solution
        # =======================================================
        $d = Get-Date;
                
        $syncItemWorkspacePath = [System.IO.Path]::Combine($workspacePath, $syncItem.Name);
        $solutionWorkspacePath = [System.IO.Path]::Combine($syncItemWorkspacePath, $solution.Name);
        
        $logPath = $solutionPath.Replace(".zip", "-SolutionPackager.log");
        Write-Host "  > $d : Unpacking solution  to path '$solutionWorkspacePath' ... " -NoNewline;

        $processArgs = [String]::Concat('/action:Extract /zipfile:"', $solutionPath, '" /folder:"', $solutionWorkspacePath, '" /clobber /errorlevel:Verbose /log:"', $logPath, '" /allowDelete:Yes /allowWrite:Yes');
        $process = "$PSScriptRoot\Assemblies\SolutionPackager.exe";
        Start-Process -FilePath  $process -ArgumentList $processArgs -Wait -Verbose -Debug;
        Write-Host "done!" -ForegroundColor Green;
        Log-Info "Unpacking solution ... done!";
    }

    # =======================================================
    # Checkin modifications to TFS Source Control
    # =======================================================
    $d = Get-Date;
    Write-Host "  > $d : Checking pending changes to TFS ... " -NoNewline;
    $workspaceInfo = [Microsoft.TeamFoundation.VersionControl.Client.Workstation]::Current.GetLocalWorkspaceInfo($workspacePath);
    $workspace = $workspaceInfo.GetWorkspace($tfsCollection);    
    $workspace.PendAdd($workspacePath, $true);

    $pendingChanges = $workspace.GetPendingChanges() | Where-Object {$_.LocalItem.StartsWith($solutionWorkspacePath) };
    try
    {
        $pendingChangesCount = $pendingChanges.Count;

        # Ignore solution.xml if it's the only modifications
        $processCheckin = $true;
		if($pendingChangesCount -eq 0)
        {
            $processCheckin = $false;
			Write-Host "ignored! (nothing to checkin)" -ForegroundColor Green;
            Log-Info "Checking-in modifications to TFS... ignored (nothing to checkin)!";
		}
        elseif($pendingChangesCount -eq 1)
        {
            $pendingChange = $pendingChanges | Select-Object -First 1;
            if($pendingChange.LocalItem.Contains("Solution.xml"))
            {
                $processCheckin = $false;
                Write-Host "ignored! (solution.xml)" -ForegroundColor Green;
                Log-Info "Checking-in modifications to TFS... ignored (solution.xml)!";
                $workspace.Undo($pendingChanges);
            }
        }

        if($processCheckin)
        {
            $result = $workspace.CheckIn($pendingChanges, "Crm To Tfs Synchronization : $pendingChangesCount item(s)");
            Write-Host "done! (ChangeSet : $result)" -ForegroundColor Green;
            Log-Info "Checking-in modifications to TFS... done!";
        }
    }
    catch [Exception]
    {
        Write-Host "failed! [Error : $_.Exception]" -ForegroundColor Red;
        Log-Error "Checking-in modifications to TFS... failed! [Error : $_.Exception]";
        return;
    }

    $d = Get-Date;
    Write-Host "$d - Crm To Tfs synchronization stop for '$syncItemName'" -ForegroundColor Cyan;

}
