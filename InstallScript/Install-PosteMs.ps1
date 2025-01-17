# Fonction pour vérifier si un package est installé avec winget et l'installer si nécessaire
function Install-PackageVerbose {
    param (
        [string]$packageName
    )
    $result = winget list $packageName
    if ($result -notmatch $packageName) {
        Write-Host "$packageName n'est pas installé. Installation en cours..."
        winget install --id=$packageName -e
    } else {
        Write-Host "$packageName est déjà installé."
    }
}

# Demande la confirmation de l'utilisateur pour l'installation
function Request-Installation {
    param (
        [string]$message,
        [string]$defaultResponse = 'non'
    )
    $response = Read-Host "$message (par défaut: $defaultResponse)"
    if ([string]::IsNullOrWhiteSpace($response)) {
        $response = $defaultResponse
    }
    return $response -eq 'oui'
}

# Fonction pour télécharger et installer Msty
function Install-Myapp {
    param (
        [string]$url,
        [string]$fileName
    )
    $downloadPath = "$env:USERPROFILE\Downloads\$fileName"
    Invoke-WebRequest -Uri $url -OutFile $downloadPath
    Start-Process -FilePath $downloadPath -Wait
    Remove-Item -Path $downloadPath
}

# Installer Git et GitHub Desktop
Install-PackageVerbose -packageName Git.Git
Install-PackageVerbose -packageName GitHub.GitHubDesktop

# Installer des éditeurs de texte et des outils de développement
Install-PackageVerbose -packageName appmakes.Typora
Install-PackageVerbose -packageName Altap.Salamander
Install-PackageVerbose -packageName DevToys-app.DevToys
Install-PackageVerbose -packageName Doist.Todoist
Install-PackageVerbose -packageName Microsoft.PowerToys
Install-PackageVerbose -packageName Microsoft.PowerShell
Install-PackageVerbose -packageName JanDeDobbeleer.OhMyPosh
Install-PackageVerbose -packageName dotPDN.PaintDotNet
Install-PackageVerbose -packageName Microsoft.PowerAppsCLI
Install-PackageVerbose -packageName M2Team.NanaZip
Install-PackageVerbose -packageName Bruno.Bruno
Install-PackageVerbose -packageName Obsidian.Obsidian

# Installer les outils Sysinternals
Install-PackageVerbose -packageName Microsoft.Sysinternals.ZoomIt
Install-PackageVerbose -packageName Microsoft.Sysinternals.ProcessExplorer
Install-PackageVerbose -packageName Microsoft.Sysinternals.Autoruns

# Installer WhatsApp
Install-PackageVerbose -packageName 9NKSQGP7F2NH

# Installer Microsoft Edge Dev
Install-PackageVerbose -packageName Microsoft.Edge.Dev

# Télécharger et installer la police CascadiaCode
# https://github.com/ryanoasis/nerd-fonts/releases/download/v3.2.1/CascadiaCode.zip
# Unblock-File -Path .\CascadiaCode.zip
# Expand-Archive .\CascadiaCode.zip
# cd .\CascadiaCode\

# Demander si l'utilisateur souhaite installer les outils IA
if (Request-Installation "Voulez-vous installer les outils IA ? (oui/non)") {
    
    # Installer Ollama
    Install-PackageVerbose -packageName Ollama.Ollama
    
    # Installer Msty: interface graphique pour les outils IA
    $version = Read-Host "Voulez-vous la version 'x64 GPU' ou 'x64 CPU Only' ?"
    if ($version -eq 'x64 GPU') {
        Install-Myapp -url "https://assets.msty.app/win/auto/Msty_x64.exe" -fileName "Msty_x64.exe"
    } elseif ($version -eq 'x64 CPU Only') {
        Install-Myapp -url "https://assets.msty.app/Msty_x64.exe" -fileName "Msty_x64.exe"
    } else {
        Write-Host "Version non reconnue. Installation annulée."
    }
}