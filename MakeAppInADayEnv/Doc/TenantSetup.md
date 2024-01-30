# Setup App in a day tenant

This document is intended to help setup a tenant provisioned from demos.microsoft.com to run the App in a day workshop. The script provides a set of commands to automate creating users, assigning licenses, and creating a trial environment with Microsoft Dataverse for each user.

> [!WARNING]
>
> Do not use this on your production live tenants as it does delete users and environments.

This setup process is documented to use the Windows PowerShell ISE application. If you aren’t familiar with it you can find more information here https://docs.microsoft.com/en-us/powershell/scripting/components/ise/introducing-the-windows-powershell-ise?view=powershell-6 

## Step 1 - Create new Demo tenant

- Sign up for a new demo at https://aka.ms/ppa/trial 
- **Open a new private browser session** and go to https://admin.microsoft.com 
  - Login with your new credentials for your demo tenant.
  - Go to **Billing ->Purchase Services** and Search on Office 365 E3 (Make sure you do **Office 365 E3** not Microsoft 365 E3) – Click Get free trial. 
  - Confirm the service.
- Assign a Power Apps per User license to your admin user
- In the same browser sessions, navigate to https://aka.ms/ppac and make sure you can see the default environment.
  - Click on the default environment.
  - Click **Edit**.
  - Change the environment name to **Personal Productivity** and click **Save**.

## Step 2 - Run Setup Script

> [!NOTE]
>
> If you receive errors or messages not documented in these steps, review the known issues below for possible resolution.

- From Windows Start search on and run the **Windows PowerShell ISE** application.

- **File** -> **Open** ->**Setup.ps1.**

- Run the script by pressing F5 or by clicking the play icon. This just loads the setup commands it does not start the actual setup process. You will know this is completed when the command prompt becomes available again.

- Run the **Start-AppInADay-Setup** command; use the parameters to provide tenant and configuration information like shown in the following example commands:

  - Europe tenant example:
    `Start-AppInADay-Setup -TenantName MX12345ABC -CDSLocation Europe -UserCount 24`

  - France tenant example: 

    `Start-AppInADay-Setup -TenantName MX12345ABC -CDSLocation France -UserCount 24` 

  - Other regions should locate their local API url for their commands: https://docs.microsoft.com/powershell/powerapps/overview?view=pa-ps-latest#service-url
  - When choosing your User Count keep in mind the number of licenses you have available
  - When you are prompted for your tenant admin account **make sure to provide the account only for your demo tenant admin.**
  - You can get parameter help using: 
    `get-help Start-AppInADay-Setup -Detailed`



This should now cycle through creating your users and their environments. This may take several minutes. You will see a command prompt when this is complete. Review the log for any errors you may need to address. You may re-run the setup script to attempt to resolve errors that occurred during the prior run.

It’s always good to manually review a few of the users and environments prior to your event.

The users that are created follow a naming convention of [labadminXX@yourtenant.onmicrosoft.com](mailto:labadminXX@yourtenant.onmicrosoft.com); with a password of test@word1. The XX is replaced by the numbered user up to the number of users you provisioned with the script.



> [!NOTE]
>
> If you have incompatible PowerShell modules already installed you might get an error prompting you to run CleanupOldModules.ps1. Close all PowerShell sessions and run this script which will remove all PowerShell modules used by the setup script so the setup script can then install the versions it requires.

# Other commands available

- In the event CDS provisioning does not complete you can run just that using the command to finish that part of setup:
  `Resume-AppInADay-CDSProvisioning`

- After an event if you want to remove the environments, you can use the command will delete all the student environments:
  `Cleanup-AppInADay`

- If you want to reset and create new environments use will remove all student environments and create additional ones:
  `Reset-AppInADay`



# Known Issues

- You might receive warning messages about PSGallery – if you wish to suppress those messages you can use the following command to change your trust level on the gallery. 
  `Set-PSRepository -Name PSGallery -InstallationPolicy Trusted`

- Some computers have restrictive policies for running unsigned scripts – you can adjust your execution policy using the information provided here if needed https://go.microsoft.com/fwlink/?LinkID=135170 
- Sometimes on copy and paste line spacing loses formatting. If the behavior is not as expected, review the spacing.