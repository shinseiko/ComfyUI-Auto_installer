#Requires -RunAsAdministrator

<#
.SYNOPSIS
    An automated installer for ComfyUI and its dependencies.
.DESCRIPTION
    This script streamlines the setup of ComfyUI, including Python, Git,
    all required Python packages, custom nodes, and optional models.
#>

#===========================================================================
# SECTION 1: SCRIPT CONFIGURATION & HELPER FUNCTIONS
#===========================================================================

param(
    [string]$InstallPath = (Split-Path -Path $PSScriptRoot -Parent)
)
$comfyPath = Join-Path $InstallPath "ComfyUI"
$scriptPath = Join-Path $InstallPath "scripts"
$condaPath = Join-Path $env:LOCALAPPDATA "Miniconda3"
$condaExe = Join-Path $condaPath "Scripts\conda.exe"
$logPath = Join-Path $InstallPath "logs"
$logFile = Join-Path $logPath "install_log.txt"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$dependenciesFile = Join-Path (Split-Path -Path $MyInvocation.MyCommand.Definition -Parent) "dependencies.json"
if (-not (Test-Path $dependenciesFile)) { Write-Host "FATAL: dependencies.json not found..." -ForegroundColor Red; Read-Host; exit 1 }
$dependencies = Get-Content -Raw -Path $dependenciesFile | ConvertFrom-Json
if (-not (Test-Path $logPath)) { New-Item -ItemType Directory -Force -Path $logPath | Out-Null }

function Write-Log {
    param([string]$Message, [int]$Level = 1, [string]$Color = "Default")
    $prefix = ""
    $defaultColor = "White"
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    switch ($Level) {
        -2 { $prefix = "" }
        0 {
            $global:currentStep++
            $wrappedMessage = "| [Step $($global:currentStep)/$($global:totalSteps)] $Message |"
            $separator = "=" * ($wrappedMessage.Length)
            $consoleMessage = "`n$separator`n$wrappedMessage`n$separator"
            $logMessage = "[$timestamp] [Step $($global:currentStep)/$($global:totalSteps)] $Message"
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
    Add-Content -Path $logFile -Value $logMessage
}

function Invoke-AndLog {
    param(
        [string]$File,
        [string]$Arguments,
        [switch]$IgnoreErrors
    )
    
    # Chemin vers un fichier log temporaire unique.
    $tempLogFile = Join-Path $env:TEMP ([System.Guid]::NewGuid().ToString() + ".tmp")

    try {
        Write-Log "Executing: $File $Arguments" -Level 3 -Color DarkGray

        # CONSTRUIT la chaîne de commande complète pour Invoke-Expression.
        # Nous mettons $File entre guillemets (au cas où il contiendrait des espaces)
        # et nous laissons $Arguments tel quel pour que PowerShell puisse l'analyser.
        # Tous les flux (*>&1) sont redirigés vers le fichier temporaire.
        $CommandToRun = "& `"$File`" $Arguments *>&1 | Out-File -FilePath `"$tempLogFile`" -Encoding utf8"
        
        # EXÉCUTE la chaîne de commande
        Invoke-Expression $CommandToRun
        
        # Lit le fichier temporaire.
        $output = if (Test-Path $tempLogFile) { Get-Content $tempLogFile } else { @() }
        
        # Vérifie le code de sortie du processus natif
        if ($LASTEXITCODE -ne 0 -and -not $IgnoreErrors) {
            Write-Log "ERREUR: La commande a échoué avec le code $LASTEXITCODE." -Color Red
            Write-Log "Commande: $File $Arguments" -Color Red
            Write-Log "Sortie de l'erreur:" -Color Red
            
            # Affiche l'erreur dans la console ET dans le log
            $output | ForEach-Object {
                Write-Host $_ -ForegroundColor Red
                Add-Content -Path $logFile -Value $_
            }
            
            # Arrête le script
            throw "L'exécution de la commande a échoué. Vérifiez les logs."
        } else {
            # Si tout va bien, ajoute la sortie au log principal
            Add-Content -Path $logFile -Value $output
        }

    } catch {
        # Cela attrape le 'throw' ci-dessus ou une erreur PowerShell
        Write-Log "ERREUR FATALE lors de la tentative d'exécution: $File $Arguments" -Color Red
        $errorMsg = $_ | Out-String
        Write-Log $errorMsg -Color Red
        Add-Content -Path $logFile -Value $errorMsg
        
        # Stoppe le script et attend que l'utilisateur lise l'erreur
        Read-Host "Une erreur fatale est survenue. Appuyez sur Entrée pour quitter."
        exit 1
    } finally {
        # S'assure que le fichier temporaire est toujours supprimé.
        if (Test-Path $tempLogFile) {
            Remove-Item $tempLogFile -ErrorAction SilentlyContinue
        }
    }
}

function Download-File {
    param([string]$Uri, [string]$OutFile)
    Write-Log "Downloading `"$($Uri.Split('/')[-1])`"" -Level 2 -Color DarkGray
    Invoke-AndLog "powershell.exe" "-NoProfile -Command `"[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; Invoke-WebRequest -Uri '$Uri' -OutFile '$OutFile'`""
}

function Invoke-Conda-Command {
    param(
        [string]$Command,
        [string]$Arguments
    )
    # Plus besoin de $condaRun, on utilise $condaExe qui est défini globalement
    Invoke-AndLog $condaExe "run --no-capture-output --no-activate -n UmeAiRT $Command $Arguments"
}

function Invoke-Conda-Build-Command {
    param(
        [string]$Command,
        [string]$Arguments
    )
    # Cette version OMET --no-activate pour forcer l'exécution
    # des scripts d'activation du compilateur (et accepte le "cls").
    Invoke-AndLog $condaExe "run --no-capture-output -n UmeAiRT $Command $Arguments"
}
#===========================================================================
# SECTION 2: MAIN SCRIPT EXECUTION
#===========================================================================
Write-Host "`n>>> CONFIRMATION: RUNNING FINAL SCRIPT <<<`n" -ForegroundColor Green
Write-Log "DEBUG: Loaded tools config: $($dependencies.tools | ConvertTo-Json -Depth 3)" -Level 3
$global:totalSteps = 11
$global:currentStep = 0
$totalCores = [int]$env:NUMBER_OF_PROCESSORS
$optimalParallelJobs = [int][Math]::Floor(($totalCores * 3) / 4)
if ($optimalParallelJobs -lt 1) { $optimalParallelJobs = 1 }

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
Write-Host "                           ComfyUI - Auto-Installer                            " -ForegroundColor Yellow
Write-Host "                                  Version 3.2                                  " -ForegroundColor White
Write-Host "-------------------------------------------------------------------------------"

# --- Step 1: Setup Miniconda and Conda Environment ---
Write-Log "Setting up Miniconda and Conda Environment" -Level 0
if (-not (Test-Path $condaPath)) {
    Write-Log "Miniconda not found. Installing..." -Level 1 -Color Yellow
    $minicondaInstaller = Join-Path $env:TEMP "Miniconda3-latest-Windows-x86_64.exe"
    Download-File -Uri "https://repo.anaconda.com/miniconda/Miniconda3-py312_25.7.0-2-Windows-x86_64.exe" -OutFile $minicondaInstaller
    Start-Process -FilePath $minicondaInstaller -ArgumentList "/InstallationType=JustMe /RegisterPython=0 /S /D=$condaPath" -Wait
    Remove-Item $minicondaInstaller
} else {
    Write-Log "Miniconda is already installed" -Level 1 -Color Green
}
Write-Log "Accepting Anaconda Terms of Service..." -Level 1
Invoke-AndLog "$condaExe" "tos accept --override-channels --channel https://repo.anaconda.com/pkgs/main"
Invoke-AndLog "$condaExe" "tos accept --override-channels --channel https://repo.anaconda.com/pkgs/r"
Invoke-AndLog "$condaExe" "tos accept --override-channels --channel https://repo.anaconda.com/pkgs/msys2"

Write-Log "Checking for VS Build Tools" -Level 1
$vsTool = $dependencies.tools.vs_build_tools
if (-not (Test-Path $vsTool.install_path)) {
    Write-Log "VS Build Tools not found. Installing..." -Level 1 -Color Yellow
    $vsInstaller = Join-Path $env:TEMP "vs_buildtools.exe"
    Download-File -Uri $vsTool.url -OutFile $vsInstaller
    Start-Process -FilePath $vsInstaller -ArgumentList $vsTool.arguments -Wait
    Remove-Item $vsInstaller
}
else {
    Write-Log "Visual Studio Build Tools are already installed" -Level 1 -Color Green
}


$envExists = Invoke-AndLog "$condaExe" "env list" | Select-String -Pattern "UmeAiRT"
if (-not $envExists) {
    Write-Log "Creating Conda environment 'UmeAiRT'..." -Level 1
    Invoke-AndLog "$condaExe" "env create -f `"$scriptPath\environment.yml`""
} else {
    Write-Log "Conda environment 'UmeAiRT' already exists" -Level 1 -Color Green
}
Write-Log "Environnement Conda prêt." -Level 1 -Color Green

# --- DÉBUT DU LANCEUR DE LA PHASE 2 ---
Write-Log "Lancement de la Phase 2 de l'installation..." -Level 0

# Crée un fichier .bat pour lancer la phase 2 DANS l'environnement Conda
$phase2LauncherPath = Join-Path $scriptPath "Launch-Phase2.bat"
$phase2ScriptPath = Join-Path $scriptPath "Phase2-Install.ps1"

$launcherContent = @"
@echo off
echo Activando entorno UmeAiRT...
call "$($condaExe -replace 'conda.exe', 'activate.bat')" UmeAiRT
if %errorlevel% neq 0 (
    echo ECHEC de l'activation de Conda.
    pause
    exit /b %errorlevel%
)

echo Lancement de la Phase 2 (PowerShell)...
powershell.exe -ExecutionPolicy Bypass -File "$phase2ScriptPath"
echo Fin de la Phase 2.
pause
"@

$launcherContent | Out-File -FilePath $phase2LauncherPath -Encoding utf8

# Exécute le lanceur
Invoke-AndLog $phase2LauncherPath ""

Write-Log "-------------------------------------------------------------------------------" -Color Green
Write-Log "Installation terminée !" -Color Green
Read-Host "Appuyez sur Entrée pour fermer cette fenêtre."