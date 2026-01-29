#===========================================================================
# SECTION 1: SCRIPT CONFIGURATION & HELPER FUNCTIONS
#===========================================================================

# --- Paths and Configuration ---
$InstallPath = (Split-Path -Path $PSScriptRoot -Parent)
$comfyPath = Join-Path $InstallPath "ComfyUI"
# [FIX] Target internal folder (Junctions handle the redirection to external storage)
$internalCustomNodesPath = Join-Path $comfyPath "custom_nodes"
$workflowPath = Join-Path $InstallPath "user\default\workflows\UmeAiRT-Workflow"
$condaPath = Join-Path $env:LOCALAPPDATA "Miniconda3"
$logPath = Join-Path $InstallPath "logs"
$logFile = Join-Path $logPath "update_log.txt"
$scriptPath = Join-Path $InstallPath "scripts"

# --- Load Dependencies from JSON ---
$dependenciesFile = Join-Path $scriptPath "dependencies.json"
if (-not (Test-Path $dependenciesFile)) {
    Write-Host "FATAL: dependencies.json not found at '$dependenciesFile'. Cannot proceed." -ForegroundColor Red
    Read-Host "Press Enter to exit."
    exit 1
}
$dependencies = Get-Content -Raw -Path $dependenciesFile | ConvertFrom-Json

if (-not (Test-Path $logPath)) { New-Item -ItemType Directory -Force -Path $logPath | Out-Null }

# --- Helper Functions ---
Import-Module (Join-Path $PSScriptRoot "UmeAiRTUtils.psm1") -Force
$global:logFile = $logFile
$global:totalSteps = 4
$global:currentStep = 0

#===========================================================================
# SECTION 1.5: ENVIRONMENT DETECTION
#===========================================================================
$installTypeFile = Join-Path $scriptPath "install_type"
$pythonExe = "python" # Default fallback

if (Test-Path $installTypeFile) {
    $installType = Get-Content -Path $installTypeFile -Raw
    $installType = $installType.Trim()
    
    if ($installType -eq "venv") {
        $venvPython = Join-Path $scriptPath "venv\Scripts\python.exe"
        if (Test-Path $venvPython) {
            $pythonExe = $venvPython
            Write-Host "[INIT] Detected VENV installation. Using: $pythonExe" -ForegroundColor Cyan
        }
    } elseif ($installType -eq "conda") {
        $condaEnvPython = Join-Path $env:LOCALAPPDATA "Miniconda3\envs\UmeAiRT\python.exe"
        if (Test-Path $condaEnvPython) {
            $pythonExe = $condaEnvPython
            Write-Host "[INIT] Detected CONDA installation. Using: $pythonExe" -ForegroundColor Cyan
        }
    }
} else {
    Write-Host "[WARN] 'install_type' file not found. Assuming System Python." -ForegroundColor Yellow
}

#===========================================================================
# SECTION 2: UPDATE PROCESS
#===========================================================================
Clear-Host
Write-Log "===============================================================================" -Level -2
Write-Log "             Starting UmeAiRT ComfyUI Update Process" -Level -2 -Color Yellow
Write-Log "===============================================================================" -Level -2
Write-Log "Python Executable used: $pythonExe" -Level 1

# --- 1. Update Git Repositories (Core & Workflows) ---
Write-Log "Updating Core Git repositories..." -Level 0 -Color Green
Write-Log "Updating ComfyUI Core..." -Level 1
Invoke-AndLog "git" "-C `"$comfyPath`" pull"
Write-Log "Checking main ComfyUI requirements..." -Level 1
$mainReqs = Join-Path $comfyPath "requirements.txt"
Invoke-AndLog $pythonExe "-m pip install -r `"$mainReqs`""

# --- 2. Update and Install Custom Nodes (Manager CLI) ---
Write-Log "Updating/Installing Custom Nodes..." -Level 0 -Color Green

# --- A. Update ComfyUI-Manager FIRST ---
$managerPath = Join-Path $internalCustomNodesPath "ComfyUI-Manager"
Write-Log "Updating ComfyUI-Manager..." -Level 1
if (Test-Path $managerPath) {
    Invoke-AndLog "git" "-C `"$managerPath`" pull"
} else {
    Write-Log "ComfyUI-Manager missing. Installing..." -Level 2
    Invoke-AndLog "git" "clone https://github.com/ltdrdata/ComfyUI-Manager.git `"$managerPath`""
}

# --- B. Update Manager Dependencies (Critical for CLI) ---
$managerReqs = Join-Path $managerPath "requirements.txt"
if (Test-Path $managerReqs) {
    Write-Log "Updating ComfyUI-Manager dependencies..." -Level 1
    Invoke-AndLog $pythonExe "-m pip install -r `"$managerReqs`""
}

$cmCliScript = Join-Path $managerPath "cm-cli.py"

# --- C. Setup Environment Variables for CLI ---
# This matches the logic in Phase 2 to prevent "ModuleNotFoundError"
$env:PYTHONPATH = "$comfyPath;$managerPath;$env:PYTHONPATH"
$env:COMFYUI_PATH = $comfyPath

# --- D. Snapshot vs CSV Logic ---
$snapshotFile = Join-Path $scriptPath "snapshot.json"

# --- D. Global Update Strategy ---

# 1. Restore Snapshot (if available) to ensure all nodes are present
if (Test-Path $snapshotFile) {
    Write-Log "Install missing nodes first..." -Level 1 -Color Cyan
    try {
        Invoke-AndLog $pythonExe "`"$cmCliScript`" restore-snapshot `"$snapshotFile`""
    } catch {
        Write-Log "WARNING: Snapshot restore encountered issues." -Level 1 -Color Yellow
    }
}

# 2. Update All Nodes (New & Existing)
Write-Log "Performing GLOBAL UPDATE of all custom nodes..." -Level 1 -Color Cyan
try {
    # 'update all' handles git pulls, requirements.txt, and install.py scripts automatically
    Invoke-AndLog $pythonExe "`"$cmCliScript`" update all"
    Write-Log "All custom nodes updated successfully via CLI!" -Level 1 -Color Green
} catch {
    Write-Log "ERROR: Global update failed. Check logs." -Level 1 -Color Red
}

# 3. Install local additions (from custom_nodes.local.csv)
$localCsvPath = Join-Path $scriptPath "custom_nodes.local.csv"
if (Test-Path $localCsvPath) {
    Write-Log "Loading custom_nodes.local.csv..." -Level 1 -Color Cyan
    $localNodes = Import-Csv -Path $localCsvPath
    Write-Log "Found $($localNodes.Count) local node(s) to check/install." -Level 2

    $successCount = 0
    $failCount = 0

    foreach ($node in $localNodes) {
        $nodeName = $node.Name
        $repoUrl = $node.RepoUrl
        $possiblePath = Join-Path $internalCustomNodesPath $nodeName

        if (-not (Test-Path $possiblePath)) {
            Write-Log "Installing $nodeName via CLI..." -Level 1
            try {
                Invoke-AndLog $pythonExe "`"$cmCliScript`" install $repoUrl"
                $successCount++
            }
            catch {
                Write-Log "Failed to install $nodeName via CLI." -Level 2 -Color Red
                $failCount++
            }
        }
        else {
            Write-Log "$nodeName already exists (will be updated by 'update all')." -Level 2 -Color Green
            $successCount++
        }
    }
    Write-Log "Local custom nodes: $successCount processed." -Level 1
}

# --- Cleanup Env Vars ---
$env:PYTHONPATH = $env:PYTHONPATH -replace [regex]::Escape("$comfyPath;"), ""
$env:PYTHONPATH = $env:PYTHONPATH -replace [regex]::Escape("$managerPath;"), ""
$env:COMFYUI_PATH = $null

Write-Log "===============================================================================" -Level -2
Write-Log "Update process complete!" -Level -2 -Color Yellow
Write-Log "===============================================================================" -Level -2