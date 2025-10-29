# NE PAS METTRE #Requires -RunAsAdministrator ici

<#
.SYNOPSIS
    Phase 1 : Gère les tâches admin (si nécessaire) puis installe Conda et lance Phase 2.
.DESCRIPTION
    1. Vérifie si les tâches admin (chemins longs, VS Tools, Git system) sont requises.
    2. Si oui et pas déjà admin, se relance avec élévation pour UNIQUEMENT ces tâches et attend.
    3. L'instance élevée effectue les tâches admin puis quitte.
    4. L'instance utilisateur (originale) installe Miniconda, crée l'env, lance Phase 2.
#>

#===========================================================================
# SECTION 1: SCRIPT CONFIGURATION & HELPER FUNCTIONS
#===========================================================================

param(
    [string]$InstallPath = (Split-Path -Path $PSScriptRoot -Parent),
    [switch]$RunAdminTasks # Flag pour le mode élevé
)
$comfyPath = Join-Path $InstallPath "ComfyUI"
$scriptPath = Join-Path $InstallPath "scripts"
$condaPath = Join-Path $env:LOCALAPPDATA "Miniconda3"
$condaExe = Join-Path $condaPath "Scripts\conda.exe"
$logPath = Join-Path $InstallPath "logs"
$logFile = Join-Path $logPath "install_log.txt"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# Charger les dépendances TÔT
$dependenciesFile = Join-Path $scriptPath "dependencies.json"
if (-not (Test-Path $dependenciesFile)) { Write-Host "FATAL: dependencies.json not found at '$dependenciesFile'..." -ForegroundColor Red; Read-Host; exit 1 }
try { $dependencies = Get-Content -Raw -Path $dependenciesFile | ConvertFrom-Json } catch { Write-Host "FATAL: Failed to parse dependencies.json. Error: $($_.Exception.Message)" -ForegroundColor Red; Read-Host; exit 1}
if (-not (Test-Path $logPath)) { try { New-Item -ItemType Directory -Force -Path $logPath | Out-Null } catch { Write-Host "WARN: Could not create log directory '$logPath'" -ForegroundColor Yellow } }

function Test-IsAdmin {
    try {
        $currentUser = New-Object Security.Principal.WindowsPrincipal $([Security.Principal.WindowsIdentity]::GetCurrent())
        return $currentUser.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    } catch { return $false } # En cas d'erreur, suppose qu'on n'est pas admin
}

# --- Définition des fonctions Write-Log, Invoke-AndLog, Download-File ---
# (Ces fonctions ne sont utilisées QUE par le mode utilisateur normal)

function Write-Log {
    param([string]$Message, [int]$Level = 1, [string]$Color = "Default")
    $prefix = ""
    $defaultColor = "White"
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    try {
        switch ($Level) {
            -2 { $prefix = "" }
            0 {
                $global:currentStep++
                $stepStr = "[Step $($global:currentStep)/$($global:totalSteps)]"
                $wrappedMessage = "| $stepStr $Message |"
                $separator = "=" * ($wrappedMessage.Length)
                $consoleMessage = "`n$separator`n$wrappedMessage`n$separator"
                $logMessage = "[$timestamp] $stepStr $Message"
                $defaultColor = "Yellow"
            }
            1 { $prefix = "  - " }
            2 { $prefix = "    -> " }
            3 { $prefix = "      [INFO] " }
        }
        if ($Color -eq "Default") { $Color = $defaultColor }
        if ($Level -ne 0) {
            $logMessage = "[$timestamp] $($prefix.Trim()) $Message"
            $consoleMessage = "$prefix$Message"
        }
        Write-Host $consoleMessage -ForegroundColor $Color
        Add-Content -Path $logFile -Value $logMessage -ErrorAction SilentlyContinue # Tente d'écrire, ignore si échec (ex: droits)
    } catch {
        Write-Host "Erreur interne dans Write-Log: $($_.Exception.Message)" -ForegroundColor Red
    }
}

function Invoke-AndLog {
    param( [string]$File, [string]$Arguments, [switch]$IgnoreErrors )
    $tempLogFile = Join-Path $env:TEMP ([System.Guid]::NewGuid().ToString() + ".tmp")
    try {
        Write-Log "Executing: $File $Arguments" -Level 3 -Color DarkGray
        $CommandToRun = "& `"$File`" $Arguments *>&1 | Out-File -FilePath `"$tempLogFile`" -Encoding utf8"
        Invoke-Expression $CommandToRun
        $output = if (Test-Path $tempLogFile) { Get-Content $tempLogFile } else { @() }
        if ($LASTEXITCODE -ne 0 -and -not $IgnoreErrors) {
            Write-Log "ERREUR: La commande a échoué avec le code $LASTEXITCODE." -Color Red
            Write-Log "Commande: $File $Arguments" -Color Red
            Write-Log "Sortie de l'erreur:" -Color Red
            $output | ForEach-Object { Write-Host $_ -ForegroundColor Red; Add-Content -Path $logFile -Value $_ -ErrorAction SilentlyContinue }
            throw "L'exécution de la commande a échoué. Vérifiez les logs."
        } else { Add-Content -Path $logFile -Value $output -ErrorAction SilentlyContinue }
    } catch {
        $errMsg = "ERREUR FATALE lors de la tentative d'exécution: $File $Arguments. Erreur: $($_.Exception.Message)"
        Write-Log $errMsg -Color Red
        Add-Content -Path $logFile -Value $errMsg -ErrorAction SilentlyContinue
        Read-Host "Une erreur fatale est survenue. Appuyez sur Entrée pour quitter."
        exit 1
    } finally { if (Test-Path $tempLogFile) { Remove-Item $tempLogFile -ErrorAction SilentlyContinue } }
}

function Download-File {
    param([string]$Uri, [string]$OutFile)
    Write-Log "Downloading `"$($Uri.Split('/')[-1])`"" -Level 2 -Color DarkGray
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        Invoke-WebRequest -Uri $Uri -OutFile $OutFile -UseBasicParsing -ErrorAction Stop
        Write-Log "Download successful." -Level 3
    } catch {
        Write-Log "ERREUR: Download failed for '$Uri'. Error: $($_.Exception.Message)" -Color Red
        throw "Download failed."
    }
}

#===========================================================================
# SECTION 2: MAIN SCRIPT EXECUTION
#===========================================================================
$global:totalSteps = 2 # Phase 1 = Setup Admin (si besoin) + Setup Conda Env + Lancement Phase 2
$global:currentStep = 0

# --- Logique d'élévation ---
if ($RunAdminTasks) {
    # --- Mode Admin : Exécute UNIQUEMENT les tâches admin ---
    # Utilise Write-Host car Write-Log pourrait ne pas être totalement initialisé ou avoir des pbs de droits
    Write-Host "`n=== Exécution des tâches Administrateur ===`n" -ForegroundColor Cyan

    # Tâche 1 : Chemins Longs
    Write-Host "[Admin Task 1/3] Activation du support des chemins longs (Registre)..." -ForegroundColor Yellow
    $regPath = "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem"; $regKey = "LongPathsEnabled"
    try {
        if ((Get-ItemPropertyValue -Path $regPath -Name $regKey -ErrorAction SilentlyContinue) -ne 1) {
            Set-ItemProperty -Path $regPath -Name $regKey -Value 1 -Type DWord -Force -ErrorAction Stop
            Write-Host "- Support des chemins longs activé." -ForegroundColor Green
        } else { Write-Host "- Support des chemins longs déjà activé." -ForegroundColor Green }
    } catch { Write-Host "- ERREUR: Impossible d'activer les chemins longs. $_" -ForegroundColor Red }

    # Tâche 2 : VS Build Tools
    Write-Host "[Admin Task 2/3] Vérification/Installation des VS Build Tools..." -ForegroundColor Yellow
    $depFileAdmin = Join-Path $scriptPath "dependencies.json" # Re-détermine le chemin
    $vsToolAdmin = $null
    if (Test-Path $depFileAdmin) {
        try { $depsAdmin = Get-Content -Raw -Path $depFileAdmin | ConvertFrom-Json } catch { $depsAdmin = $null }
        if ($depsAdmin -ne $null -and $depsAdmin.PSObject.Properties.Name -contains 'tools' -and $depsAdmin.tools.PSObject.Properties.Name -contains 'vs_build_tools') {
             $vsToolAdmin = $depsAdmin.tools.vs_build_tools
        }
    }
    if ($vsToolAdmin -ne $null -and $vsToolAdmin.install_path) {
        $vsInstallCheckPathAdmin = $ExecutionContext.InvokeCommand.ExpandString($vsToolAdmin.install_path)
        if (-not (Test-Path $vsInstallCheckPathAdmin)) {
            Write-Host "- Installation des VS Build Tools..." -ForegroundColor Yellow
            $vsInstallerAdmin = Join-Path $env:TEMP "vs_buildtools_admin.exe"
            try {
                [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
                Invoke-WebRequest -Uri $vsToolAdmin.url -OutFile $vsInstallerAdmin -UseBasicParsing -ErrorAction Stop
                Write-Host "- Lancement de l'installeur VS Build Tools (peut prendre du temps)..."
                Start-Process -FilePath $vsInstallerAdmin -ArgumentList $vsToolAdmin.arguments -Wait -ErrorAction Stop
                Remove-Item $vsInstallerAdmin -ErrorAction SilentlyContinue
                Write-Host "- VS Build Tools installés." -ForegroundColor Green
            } catch { Write-Host "- ERREUR: Échec du téléchargement/installation des VS Build Tools. $_" -ForegroundColor Red }
        } else { Write-Host "- VS Build Tools déjà installés." -ForegroundColor Green }
    } else { Write-Host "- ERREUR: Impossible de trouver les informations VS Build Tools dans '$depFileAdmin'." -ForegroundColor Red }

    # Tâche 3 : Git Config System
    Write-Host "[Admin Task 3/3] Configuration de Git (système) pour les chemins longs..." -ForegroundColor Yellow
    $gitExeAdmin = Get-Command git -ErrorAction SilentlyContinue
    if ($gitExeAdmin) {
        try {
            Start-Process $gitExeAdmin.Source -ArgumentList "config --system core.longpaths true" -Wait -NoNewWindow -ErrorAction Stop
            Write-Host "- Configuration Git --system terminée." -ForegroundColor Green
        } catch { Write-Host "- ERREUR lors de la configuration Git --system: $($_.Exception.Message)" -ForegroundColor Red }
    } else { Write-Host "- AVERTISSEMENT: 'git' introuvable dans le PATH. Impossible de configurer --system core.longpaths." -ForegroundColor Yellow }

    Write-Host "`n=== Tâches admin terminées. Fermeture de cette fenêtre. ===" -ForegroundColor Green
    Start-Sleep -Seconds 3 # Laisse le temps de lire
    exit 0 # <<<=== QUITTER LE SCRIPT ADMIN ICI

} else {
    # --- Mode Utilisateur Normal ---

    # Vérifie si l'élévation est nécessaire
    $needsElevation = $false
    Write-Log "Vérification des prérequis nécessitant potentiellement les droits admin..." -Level 1
    # Chemins longs
    if ((Get-ItemPropertyValue -Path "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem" -Name "LongPathsEnabled" -ErrorAction SilentlyContinue) -ne 1) {
        Write-Log "Le support des chemins longs doit être activé (Admin requis)." -Level 2 -Color Yellow; $needsElevation = $true
    } else { Write-Log "Support chemins longs OK." -Level 2 -Color Green }
    # VS Build Tools
    if ($dependencies -ne $null -and $dependencies.tools -ne $null -and $dependencies.tools.vs_build_tools -ne $null -and $dependencies.tools.vs_build_tools.install_path) {
        $vsInstallCheckPath = $ExecutionContext.InvokeCommand.ExpandString($dependencies.tools.vs_build_tools.install_path)
        if (-not (Test-Path $vsInstallCheckPath)) {
            Write-Log "Les VS Build Tools doivent être installés (Admin requis)." -Level 2 -Color Yellow; $needsElevation = $true
        } else { Write-Log "VS Build Tools OK." -Level 2 -Color Green }
    } else { Write-Log "AVERTISSEMENT: Impossible de vérifier VS Build Tools (dependencies.json?). L'élévation pourrait être nécessaire." -Level 2 -Color Yellow; $needsElevation = $true }
    # Git Config System
    $gitExeUser = Get-Command git -ErrorAction SilentlyContinue
    $gitLongPathsSystemEnabled = $false
    if ($gitExeUser) {
        $gitConfigOutput = Invoke-Expression "$($gitExeUser.Source) config --system core.longpaths" 2>$null
        if ($LASTEXITCODE -eq 0 -and $gitConfigOutput -match 'true') { $gitLongPathsSystemEnabled = $true }
    }
    if (-not $gitLongPathsSystemEnabled) {
         Write-Log "La configuration Git (--system core.longpaths) doit être activée (Admin requis)." -Level 2 -Color Yellow; $needsElevation = $true
    } else { Write-Log "Config Git system OK." -Level 2 -Color Green }

    # Si l'élévation est nécessaire ET qu'on n'est pas déjà admin
    if ($needsElevation -and -not (Test-IsAdmin)) {
        Write-Host "`nDes privilèges administrateur sont requis pour la configuration initiale." -ForegroundColor Yellow
        Write-Host "Relancement d'une partie du script avec élévation..." -ForegroundColor Yellow
        Write-Host "Veuillez accepter l'invite UAC." -ForegroundColor Yellow
        $psArgs = "-ExecutionPolicy Bypass -NoProfile -File `"$($MyInvocation.MyCommand.Definition)`" -RunAdminTasks -InstallPath `"$InstallPath`""
        try {
            $adminProcess = Start-Process powershell.exe -Verb RunAs -ArgumentList $psArgs -Wait -PassThru -ErrorAction Stop
            if ($adminProcess.ExitCode -ne 0) { throw "Le processus administrateur a échoué (code $($adminProcess.ExitCode))." }
            Write-Host "`nConfiguration admin terminée avec succès. Reprise de l'installation..." -ForegroundColor Green; Start-Sleep 2
        } catch {
            Write-Host "ERREUR: Échec de l'élévation ou script admin échoué: $($_.Exception.Message)" -ForegroundColor Red
            Read-Host "Appuyez sur Entrée pour quitter."; exit 1
        }
    } elseif ($needsElevation -and (Test-IsAdmin)) {
         Write-Host "`nAVERTISSEMENT: Le script a été lancé en Admin, mais l'élévation était nécessaire." -ForegroundColor Yellow
         Write-Host "Les tâches admin seront effectuées, mais le reste s'exécutera aussi en Admin." -ForegroundColor Yellow
         # Exécute les tâches admin directement dans ce processus
         # (Copier/coller simplifié du bloc $RunAdminTasks, mais avec Write-Log)
         Write-Log "[Admin Tasks within User Script] Exécution des tâches Admin..." -Level 1
         $regPath = "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem"; $regKey = "LongPathsEnabled"
         try { Set-ItemProperty -Path $regPath -Name $regKey -Value 1 -Type DWord -Force -ErrorAction Stop; Write-Log "[Admin] Chemins longs OK." -Level 2 } catch { Write-Log "[Admin] ERREUR Chemins longs" -Level 2 -Color Red}
         # ... (Ajouter VS Tools et Git config ici si besoin de les exécuter même si lancé en admin) ...
         # NOTE: C'est un cas limite, idéalement l'utilisateur ne lance pas en admin.
    }

    # --- Le script continue ICI en tant qu'utilisateur normal ---

    Clear-Host
    # --- Bannière ---
    Write-Host "-------------------------------------------------------------------------------"
    $asciiBanner = @'
                          __  __               ___    _ ____  ______
                         / / / /___ ___  ___  /   |  (_) __ \/_  __/
                        / / / / __ `__ \/ _ \/ /| | / / /_/ / / / 
                       / /_/ / / / / / /  __/ ___ |/ / _, _/ / /
                       \____/_/ /_/ /_/\___/_/  |_/_/_/ |_| /_/
'@
    Write-Host $asciiBanner -ForegroundColor Cyan
    Write-Host "-------------------------------------------------------------------------------"
    Write-Host "                           ComfyUI - Auto-Installer (Phase 1)                   " -ForegroundColor Yellow
    Write-Host "                                  Version 3.2                                  " -ForegroundColor White
    Write-Host "-------------------------------------------------------------------------------"


    # --- Step 1: Setup Miniconda and Conda Environment ---
    Write-Log "Setting up Miniconda and Conda Environment" -Level 0 # Étape 1/2
    if (-not (Test-Path $condaPath)) {
        Write-Log "Miniconda not found. Installing..." -Level 1 -Color Yellow
        $minicondaInstaller = Join-Path $env:TEMP "Miniconda3-latest-Windows-x86_64.exe"
        $minicondaUrl = $dependencies.tools.miniconda.url # Assurez-vous d'avoir ceci dans dependencies.json
        if (-not $minicondaUrl) { $minicondaUrl = "https://repo.anaconda.com/miniconda/Miniconda3-latest-Windows-x86_64.exe" } # Fallback
        Download-File -Uri $minicondaUrl -OutFile $minicondaInstaller 
        Invoke-AndLog $minicondaInstaller "/InstallationType=JustMe /RegisterPython=0 /S /D=`"$condaPath`""
        Remove-Item $minicondaInstaller -ErrorAction SilentlyContinue
    } else { Write-Log "Miniconda is already installed at '$condaPath'" -Level 1 -Color Green }

    if (-not (Test-Path $condaExe)) { Write-Log "ERREUR FATALE: conda.exe introuvable après installation/vérification." -Color Red; Read-Host "Appuyez sur Entrée."; exit 1 }

    Write-Log "Accepting Anaconda Terms of Service..." -Level 1
    Invoke-AndLog "$condaExe" "tos accept --override-channels --channel https://repo.anaconda.com/pkgs/main"
	Invoke-AndLog "$condaExe" "tos accept --override-channels --channel https://repo.anaconda.com/pkgs/r"
	Invoke-AndLog "$condaExe" "tos accept --override-channels --channel https://repo.anaconda.com/pkgs/msys2"

    $envExistsResult = Invoke-AndLog "$condaExe" "env list" -IgnoreErrors
    $envExists = $envExistsResult -match '\bUmeAiRT\b' # Recherche plus précise

    if (-not $envExists) {
        Write-Log "Creating Conda environment 'UmeAiRT' from '$scriptPath\environment.yml'..." -Level 1
        Invoke-AndLog "$condaExe" "env create -f `"$scriptPath\environment.yml`""
    } else { Write-Log "Conda environment 'UmeAiRT' already exists" -Level 1 -Color Green }

    # --- Lancement Phase 2 ---
    Write-Log "Environnement Conda prêt." -Level 1 -Color Green
    Write-Log "Lancement de la Phase 2 de l'installation..." -Level 0 # Étape 2/2

    $phase2LauncherPath = Join-Path $scriptPath "Launch-Phase2.bat"
    $phase2ScriptPath = Join-Path $scriptPath "Install-ComfyUI-Phase2.ps1"

    $launcherContent = @"
@echo off
echo Activando entorno UmeAiRT...
call "$($condaExe -replace 'conda.exe', 'activate.bat')" UmeAiRT
if %errorlevel% neq 0 (
    echo ECHEC de l'activation de l'environnement Conda 'UmeAiRT'.
    pause
    exit /b %errorlevel%
)
echo Lancement de la Phase 2 (PowerShell)...
powershell.exe -ExecutionPolicy Bypass -NoProfile -File "$phase2ScriptPath" -InstallPath "$InstallPath"
echo Fin de la Phase 2. Appuyez sur Entree pour fermer cette fenetre.
pause
"@
    try { $launcherContent | Out-File -FilePath $phase2LauncherPath -Encoding utf8 -ErrorAction Stop } catch { Write-Log "ERREUR: Impossible de créer '$phase2LauncherPath'." -Color Red; Read-Host "Appuyez sur Entrée."; exit 1 }

    Write-Log "Ouverture d'une nouvelle fenêtre pour la Phase 2..." -Level 2
    try { Start-Process -FilePath $phase2LauncherPath -Wait -ErrorAction Stop } catch { Write-Log "ERREUR: Impossible de lancer la Phase 2 ($($_.Exception.Message))." -Color Red; Read-Host "Appuyez sur Entrée."; exit 1 }

    #===========================================================================
    # FINALIZATION (Phase 1 - Mode Utilisateur)
    #===========================================================================
    Write-Log "-------------------------------------------------------------------------------" -Color Green
    Write-Log "La Phase 1 est terminée. La Phase 2 s'est exécutée dans une fenêtre séparée." -Color Green
    # Read-Host commenté car le .bat a son propre 'pause'
    # Read-Host "Appuyez sur Entrée pour fermer cette fenêtre (Phase 1)." 
}