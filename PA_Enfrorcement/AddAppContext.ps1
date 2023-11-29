## Associate flow with an app - Change the parrameters to match your Envi ronmentName, FlowName and AppName.
Add-AdminFlowPowerAppContext -EnvironmentName fc56583f-c243-4Sf6-9Sbb-2f2d8437b3ca -FlowName fc56583f-c243-4Sf6-9Sbb-2f2d8437b3ca -AppName ft_FRP

## This scripts read theEnvi ronmentName, FlowName and AppName from the file and run the Add-AdminF10wpowerAppcontex for every row in the csv file.
$contextflows = Import-csv -Path suspensionlist.csv
ForEach ($contextflow in $contextflows)
{
    Add-AdminFlowPowerAppContext -EnvironmentName $contextflow.EnvironmentName -FlowName $contextflow.FlowName -AppName $contextflow.AppName
}

## Remove the Associate of flow with an app change the parrameters to match your Envi ronmentName, FlowName and AppName.
Remove-AdminFlowPowerAppContext -EnvironmentName fc56583f-c243-4Sf6-9Sbb-2f2d8437b3ca -FlowName fc56583f-c243-4Sf6-9Sbb-2f2d8437b3ca -AppName ft_FRP