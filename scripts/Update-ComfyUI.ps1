#===========================================================================
# SECTION 1: SCRIPT CONFIGURATION & HELPER FUNCTIONS
#===========================================================================

# --- Paths and Configuration ---
$InstallPath = (Split-Path -Path $PSScriptRoot -Parent)
$comfyPath = Join-Path $InstallPath "ComfyUI"
$customNodesPath = Join-Path $InstallPath "custom_nodes"
$workflowPath = Join-Path $InstallPath "user\default\workflows\UmeAiRT-Workflow"
$condaPath = Join-Path $env:LOCALAPPDATA "Miniconda3"
$logPath = Join-Path $InstallPath "logs"
$logFile = Join-Path $logPath "update_log.txt"

# --- Load Dependencies from JSON ---
$dependenciesFile = Join-Path $InstallPath "scripts\dependencies.json"
if (-not (Test-Path $dependenciesFile)) {
    Write-Host "FATAL: dependencies.json not found at '$dependenciesFile'. Cannot proceed." -ForegroundColor Red
    Read-Host "Press Enter to exit."
    exit 1
}
$dependencies = Get-Content -Raw -Path $dependenciesFile | ConvertFrom-Json

if (-not (Test-Path $logPath)) { New-Item -ItemType Directory -Force -Path $logPath | Out-Null }

# --- Helper Functions ---
Import-Module (Join-Path $PSScriptRoot "UmeAiRTUtils.psm1") -Force
# Définit la variable logFile globale pour que le module utilitaire puisse l'utiliser
$global:logFile = $logFile
# Définit les étapes globales (estimation)
$global:totalSteps = 3
$global:currentStep = 0

#===========================================================================
# SECTION 2: UPDATE PROCESS
#===========================================================================
Clear-Host
# [CORRECTIF] Utilisation de Level -2 pour les bannières (pas de préfixe)
Write-Log "===============================================================================" -Level -2
Write-Log "             Starting UmeAiRT ComfyUI Update Process" -Level -2 -Color Yellow
Write-Log "===============================================================================" -Level -2

# --- 1. Update Git Repositories ---
# [CORRECTIF] Utilisation de Level 0 pour les étapes
Write-Log "[1/3] Updating all Git repositories..." -Level 0 -Color Green
# [CORRECTIF] Utilisation de Level 1 pour les sous-tâches
Write-Log "Updating ComfyUI Core..." -Level 1
Invoke-AndLog "git" "-C `"$comfyPath`" pull"
Write-Log "Updating UmeAiRT Workflows..." -Level 1
Invoke-AndLog "git" "-C `"$workflowPath`" pull"

# --- 2. Update and Install Custom Nodes & Dependencies ---
Write-Log "[2/3] Updating/Installing Custom Nodes & Dependencies..." -Level 0 -Color Green
$csvUrl = $dependencies.files.custom_nodes_csv.url
$csvPath = Join-Path $InstallPath "scripts\custom_nodes.csv"
$customNodesList = Import-Csv -Path $csvPath

Write-Log "Checking all nodes based on custom_nodes.csv..." -Level 1

foreach ($node in $customNodesList) {
    $nodeName = $node.Name
    $repoUrl = $node.RepoUrl
    $nodePath = if ($node.Subfolder) { Join-Path $customNodesPath $node.Subfolder } else { Join-Path $customNodesPath $nodeName }

    # Étape 1 : Mettre à jour ou Installer
    if (Test-Path $nodePath) {
        # Le nœud existe -> Mise à jour
        # [CORRECTIF] Utilisation de Level 2 pour les sous-sous-tâches
        Write-Log "Updating $nodeName..." -Level 2 -Color Cyan
        Invoke-AndLog "git" "-C `"$nodePath`" pull"
    } else {
        # Le nœud n'existe pas -> Installation
        Write-Log "New node found: $nodeName. Installing..." -Level 2 -Color Yellow
        Invoke-AndLog "git" "clone $repoUrl `"$nodePath`""
    }

    # Étape 2 : Gérer les dépendances
    if (Test-Path $nodePath) {
        if ($node.RequirementsFile) {
            $reqPath = Join-Path $nodePath $node.RequirementsFile
            
            if (Test-Path $reqPath) {
                Write-Log "Checking requirements for $nodeName (from '$($node.RequirementsFile)')" -Level 2
                Invoke-AndLog "python" "-m pip install -r `"$reqPath`""
            }
        }
    }
}

# --- 3. Update Python Dependencies ---
Write-Log "[3/3] Updating all Python dependencies..." -Level 0 -Color Green
Write-Log "Checking main ComfyUI requirements..." -Level 1
$mainReqs = Join-Path $comfyPath "requirements.txt"
Invoke-AndLog "python" "-m pip install -r `"$mainReqs`""

# Reinstall wheel packages to ensure correct versions from JSON
Write-Log "Update wheel packages..." -Level 1
foreach ($wheel in $dependencies.pip_packages.wheels) {
    $wheelName = $wheel.name
    $wheelUrl = $wheel.url
    $localWheelPath = Join-Path $env:TEMP "$($wheelName).whl"

    Write-Log "Processing wheel: $wheelName" -Level 2 -Color Cyan

    try {
        # Download the wheel file (utilise la fonction de UmeAiRTUtils.psm1)
        Download-File -Uri $wheelUrl -OutFile $localWheelPath

        if (Test-Path $localWheelPath) {
            Invoke-AndLog "python" "-m pip install `"$localWheelPath`""
        } else {
            Write-Log "ERROR: Failed to download $wheelName" -Level 2 -Color Red
        }
    } catch {
        $errorMessage = $_.Exception.Message
        Write-Log "FATAL ERROR during processing of $wheelName : $errorMessage" -Level 2 -Color Red
    } finally {
        # Clean up the downloaded wheel file
        if (Test-Path $localWheelPath) {
            Remove-Item $localWheelPath -Force
        }
    }
}

Write-Log "===============================================================================" -Level -2
Write-Log "Update process complete!" -Level -2 -Color Yellow
Write-Log "===============================================================================" -Level -2
Read-Host "Press Enter to exit."