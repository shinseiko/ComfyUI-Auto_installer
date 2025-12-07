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

Write-Log "Updating UmeAiRT Workflows (Forcing)..." -Level 1
# Since user/ folder is now a junction, this works perfectly on external files
Write-Log "  Step 1/3: Resetting local changes (reset)..." -Level 2
Invoke-AndLog "git" "-C `"$workflowPath`" reset --hard HEAD"
Write-Log "  Step 2/3: Removing untracked local files (clean)..." -Level 2
Invoke-AndLog "git" "-C `"$workflowPath`" clean -fd"
Write-Log "  Step 3/3: Pulling updates (pull)..." -Level 2
Invoke-AndLog "git" "-C `"$workflowPath`" pull"

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

if (Test-Path $snapshotFile) {
    # --- METHOD 1: Snapshot (Preferred) ---
    Write-Log "SNAPSHOT DETECTED: Syncing nodes via Manager CLI..." -Level 1 -Color Cyan
    
    try {
        # [FIX] Using correct command: restore-snapshot
        Invoke-AndLog $pythonExe "`"$cmCliScript`" restore-snapshot `"$snapshotFile`""
        Write-Log "Snapshot sync complete!" -Level 1 -Color Green
    } catch {
        Write-Log "ERROR: Snapshot sync failed. Check logs." -Level 1 -Color Red
    }

} else {
    # --- METHOD 2: CSV Fallback ---
    Write-Log "No snapshot.json found. Falling back to custom_nodes.csv..." -Level 1 -Color Yellow
    
    $csvPath = Join-Path $InstallPath "scripts\custom_nodes.csv"
    if (Test-Path $csvPath) {
        $customNodesList = Import-Csv -Path $csvPath
        
        foreach ($node in $customNodesList) {
            $nodeName = $node.Name
            $repoUrl = $node.RepoUrl
            $nodePath = if ($node.Subfolder) { Join-Path $internalCustomNodesPath $node.Subfolder } else { Join-Path $internalCustomNodesPath $nodeName }
        
            if (Test-Path $nodePath) {
                Write-Log "Updating $nodeName (Git Pull)..." -Level 2 -Color Cyan
                # For existing nodes, simple git pull is often safer/faster than CLI reinstall
                Invoke-AndLog "git" "-C `"$nodePath`" pull"
            } else {
                Write-Log "Installing $nodeName via CLI..." -Level 2 -Color Yellow
                # Use CLI for new installs to handle install.py scripts
                try {
                    Invoke-AndLog $pythonExe "`"$cmCliScript`" install $repoUrl"
                } catch {
                    Write-Log "Failed to install $nodeName via CLI." -Level 2 -Color Red
                }
            }
        }
    } else {
        Write-Log "WARNING: custom_nodes.csv not found locally either." -Level 1 -Color Yellow
    }
}

# --- Cleanup Env Vars ---
$env:PYTHONPATH = $env:PYTHONPATH -replace [regex]::Escape("$comfyPath;"), ""
$env:PYTHONPATH = $env:PYTHONPATH -replace [regex]::Escape("$managerPath;"), ""
$env:COMFYUI_PATH = $null

# --- 3. Update Python Dependencies ---
Write-Log "Updating all Python dependencies..." -Level 0 -Color Green

# Reinstall wheel packages to ensure correct versions from JSON
Write-Log "Update wheel packages..." -Level 1
foreach ($wheel in $dependencies.pip_packages.wheels) {
    $wheelName = $wheel.name
    $wheelUrl = $wheel.url
    $localWheelPath = Join-Path $env:TEMP "$($wheelName).whl"

    Write-Log "Processing wheel: $wheelName" -Level 2 -Color Cyan

    try {
        Download-File -Uri $wheelUrl -OutFile $localWheelPath
        if (Test-Path $localWheelPath) {
            Invoke-AndLog $pythonExe "-m pip install `"$localWheelPath`""
        }
    } catch {
        Write-Log "ERROR processing $wheelName : $($_.Exception.Message)" -Level 2 -Color Red
    } finally {
        if (Test-Path $localWheelPath) { Remove-Item $localWheelPath -Force -ErrorAction SilentlyContinue }
    }
}

Write-Log "===============================================================================" -Level -2
Write-Log "Update process complete!" -Level -2 -Color Yellow
Write-Log "===============================================================================" -Level -2