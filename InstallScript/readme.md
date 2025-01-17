# InstallScript

Ce projet contient des scripts PowerShell pour installer et configurer divers outils et applications sur un poste de travail.

## Structure du projet

- `InstallScript/Install-PosteMs.ps1` : Script principal pour installer les applications et outils nécessaires.
- `CrmTfsSync/` : Contient des assemblages et des scripts pour la synchronisation CRM et TFS.
- `DeploySolutions/` : Contient des scripts pour déployer des solutions.
- `Get_PPA_SDK/` : Contient des scripts pour obtenir le SDK Dataverse.
- `MakeAppInADayEnv/` : Contient des scripts et des outils pour configurer un environnement "App in a Day".
- `PA_Enfrorcement/` : Contient des scripts pour l'application PA Enforcement.

## Utilisation

Pour exécuter le script principal d'installation, ouvrez PowerShell en tant qu'administrateur et exécutez la commande suivante :

```powershell
.\InstallScript\Install-PosteMs.ps1