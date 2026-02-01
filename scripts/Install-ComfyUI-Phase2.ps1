<#
.SYNOPSIS
    An automated installer for ComfyUI and its dependencies.
.DESCRIPTION
    This script streamlines the setup of ComfyUI, including Python, Git,
    all required Python packages, custom nodes (via ComfyUI-Manager CLI), and optional models.
#>

#===========================================================================
# SECTION 1: SCRIPT CONFIGURATION & HELPER FUNCTIONS
#===========================================================================

param(
    [string]$InstallPath = (Split-Path -Path $PSScriptRoot -Parent)
)
$comfyPath = Join-Path $InstallPath "ComfyUI"
$comfyUserPath = Join-Path $comfyPath "user"
$scriptPath = Join-Path $InstallPath "scripts"
$logPath = Join-Path $InstallPath "logs"
$logFile = Join-Path $logPath "install_log.txt"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$dependenciesFile = Join-Path (Split-Path -Path $MyInvocation.MyCommand.Definition -Parent) "dependencies.json"
if (-not (Test-Path $dependenciesFile)) { Write-Host "FATAL: dependencies.json not found..." -ForegroundColor Red; Read-Host; exit 1 }
$dependencies = Get-Content -Raw -Path $dependenciesFile | ConvertFrom-Json
if (-not (Test-Path $logPath)) { New-Item -ItemType Directory -Force -Path $logPath | Out-Null }

Import-Module (Join-Path $scriptPath "UmeAiRTUtils.psm1") -Force
$global:logFile = Join-Path $logPath "install_log.txt"
$global:hasGpu = Test-NvidiaGpu
Write-Log "DEBUG: Loaded tools config: $($dependencies.tools | ConvertTo-Json -Depth 3)" -Level 3

#===========================================================================
# SECTION 1.5: ENVIRONMENT DETECTION (SAFETY NET)
#===========================================================================
# This ensures we use the correct Python executable even if the .bat launcher wasn't used.

$installTypeFile = Join-Path $scriptPath "install_type"
$pythonExe = "python" # Default fallback (relies on PATH)

if (Test-Path $installTypeFile) {
    $iType = Get-Content -Path $installTypeFile -Raw
    $iType = $iType.Trim()
    
    if ($iType -eq "venv") {
        $venvPython = Join-Path $scriptPath "venv\Scripts\python.exe"
        if (Test-Path $venvPython) {
            $pythonExe = $venvPython
            Write-Log "VENV MODE DETECTED: Using $pythonExe" -Level 1 -Color Cyan
        }
    }
    elseif ($iType -eq "conda") {
        # Checks specifically for the UmeAiRT environment python
        $condaEnvPython = Join-Path $env:LOCALAPPDATA "Miniconda3\envs\UmeAiRT\python.exe"
        if (Test-Path $condaEnvPython) {
            $pythonExe = $condaEnvPython
            Write-Log "CONDA MODE DETECTED: Using $pythonExe" -Level 1 -Color Cyan
        }
    }
}
else {
    Write-Log "WARNING: Installation type not detected. Using system Python (if available)." -Level 1 -Color Yellow
}

#===========================================================================
# SECTION 2: MAIN SCRIPT EXECUTION
#===========================================================================
$global:totalSteps = 9
$global:currentStep = 2
$totalCores = [int]$env:NUMBER_OF_PROCESSORS
$optimalParallelJobs = [int][Math]::Floor(($totalCores * 3) / 4)
if ($optimalParallelJobs -lt 1) { $optimalParallelJobs = 1 }

Write-Log "Configuring Git to handle long paths (system-wide)..." -Level 1
try { Invoke-AndLog "git" "config --system core.longpaths true" -IgnoreErrors } catch { Write-Log "Warning: Failed to set git config (might need admin)." -Level 2 -Color Yellow }

# --- Step 2: Clone ComfyUI ---
Write-Log "Cloning ComfyUI" -Level 0
if (-not (Test-Path $comfyPath)) {
    Write-Log "Cloning ComfyUI repository from $($dependencies.repositories.comfyui.url)..." -Level 1
    $cloneArgs = "clone $($dependencies.repositories.comfyui.url) `"$comfyPath`""
    Invoke-AndLog "git" $cloneArgs

    if (-not (Test-Path $comfyPath)) {
        Write-Log "FATAL: ComfyUI cloning failed. Please check the logs." -Level 0 -Color Red
        Read-Host "Press Enter to exit."
        exit 1
    }
}
else {
    Write-Log "ComfyUI directory already exists" -Level 1 -Color Green
}

#===========================================================================
# SECTION 2.5: ARCHITECTURE SETUP (SMART MOVE logic)
#===========================================================================
Write-Log "Configuring External Folders Architecture..." -Level 0

$externalFolders = @("custom_nodes", "models", "output", "input", "user")

foreach ($folder in $externalFolders) {
    $externalPath = Join-Path $InstallPath $folder
    $internalPath = Join-Path $comfyPath $folder

    # Check if the internal folder exists (Standard ComfyUI folder from git clone)
    if (Test-Path $internalPath) {
        $item = Get-Item $internalPath
        # Only process if it's a real folder, not already a junction
        if ($item.Attributes -notmatch "ReparsePoint") {
            
            if (-not (Test-Path $externalPath)) {
                # CASE 1: External does NOT exist.
                # We MOVE the internal folder to external. This preserves subfolders (checkpoints, loras, vae...)!
                Write-Log "Moving default structure of '$folder' to external location..." -Level 1
                Move-Item -Path $internalPath -Destination $externalPath -Force
            }
            else {
                # CASE 2: External ALREADY exists (Previous install).
                # We COPY content from internal to external (to fill missing default folders), then delete internal.
                Write-Log "External '$folder' detected. Merging default structure..." -Level 1
                Copy-Item -Path "$internalPath\*" -Destination $externalPath -Recurse -Force -ErrorAction SilentlyContinue
                Remove-Item -Path $internalPath -Recurse -Force
            }
        }
    }
    elseif (-not (Test-Path $externalPath)) {
        # CASE 3: Neither exist (rare). Create empty external.
        New-Item -ItemType Directory -Force -Path $externalPath | Out-Null
    }

    # Create Junction (Internal -> External)
    if (-not (Test-Path $internalPath)) {
        cmd /c "mklink /J `"$internalPath`" `"$externalPath`"" | Out-Null
        Write-Log "Linked ComfyUI\$folder -> $folder (External)" -Level 1 -Color Cyan
    }
}

#===========================================================================
# BACK TO INSTALLATION
#===========================================================================

# --- Step 3: Install Core Dependencies ---
Write-Log "Installing Core Dependencies" -Level 0

# Check for ninja and install if missing
try {
    $ninjaCheck = & $pythonExe -m pip show ninja 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Log "Installing ninja..." -Level 1
        Invoke-AndLog $pythonExe "-m pip install ninja"
    }
}
catch {
    Write-Log "Installing ninja..." -Level 1
    Invoke-AndLog $pythonExe "-m pip install ninja"
}

Write-Log "Upgrading pip and wheel" -Level 1
Invoke-AndLog $pythonExe "-m pip install --upgrade $($dependencies.pip_packages.upgrade -join ' ')"
Write-Log "Installing torch packages" -Level 1
Invoke-AndLog $pythonExe "-m pip install $($dependencies.pip_packages.torch.packages) --index-url $($dependencies.pip_packages.torch.index_url)"

Write-Log "Installing ComfyUI requirements" -Level 1
Invoke-AndLog $pythonExe "-m pip install -r `"$comfyPath\$($dependencies.pip_packages.comfyui_requirements)`""

# --- Step 4: Install Final Python Dependencies ---
Write-Log "Installing Python Dependencies" -Level 0
Write-Log "Installing standard packages..." -Level 1
Invoke-AndLog $pythonExe "-m pip install $($dependencies.pip_packages.standard -join ' ')"

# --- Step 5: Install Custom Nodes (via ComfyUI-Manager CLI) ---
Write-Log "Installing Custom Nodes via Manager CLI" -Level 0

# Thanks to junctions, we target the internal path, but data is stored externally!
$internalCustomNodes = Join-Path $comfyPath "custom_nodes"
Write-Log "Installing UmeAiRT Sync Manager (Core Component)..." -Level 1

# 1. Install ComfyUI-Manager FIRST (Required for CLI)
$managerPath = Join-Path $internalCustomNodes "ComfyUI-Manager"
if (-not (Test-Path $managerPath)) {
    Write-Log "Installing ComfyUI-Manager (Required for CLI)..." -Level 1 -Color Cyan
    Invoke-AndLog "git" "clone https://github.com/ltdrdata/ComfyUI-Manager.git `"$managerPath`""
}

# 2. Dependencies
$managerReqs = Join-Path $managerPath "requirements.txt"
if (Test-Path $managerReqs) {
    Write-Log "Installing ComfyUI-Manager dependencies (typer, etc.)..." -Level 1
    Invoke-AndLog $pythonExe "-m pip install -r `"$managerReqs`""
}

# 3. CLI Execution
$cmCliScript = Join-Path $managerPath "cm-cli.py"
$snapshotFile = Join-Path $scriptPath "snapshot.json"

# Set PYTHONPATH so the Manager finds its local modules (utils, etc.)
$env:PYTHONPATH = "$comfyPath;$managerPath;$env:PYTHONPATH"
$env:COMFYUI_PATH = $comfyPath

if (Test-Path $snapshotFile) {
    # --- METHOD A: Snapshot (Recommended) ---
    Write-Log "Installing custom nodes from snapshot.json..." -Level 1 -Color Cyan
    Write-Log "This may take a while as it installs all nodes and dependencies..." -Level 2
    
    try {
        # Using 'restore-snapshot' command
        Invoke-AndLog $pythonExe "`"$cmCliScript`" restore-snapshot `"$snapshotFile`""
        Write-Log "Custom nodes installation complete!" -Level 1 -Color Green
    }
    catch {
        Write-Log "ERROR: Snapshot restoration failed. Check logs." -Level 1 -Color Red
    }

}
else {
    # --- METHOD B: Fallback to CSV ---
    Write-Log "No snapshot.json found. Falling back to custom_nodes.csv..." -Level 1 -Color Yellow
    
    $csvPath = Join-Path $InstallPath $dependencies.files.custom_nodes_csv.destination
    if (Test-Path $csvPath) {
        $customNodes = Import-Csv -Path $csvPath
        $successCount = 0
        $failCount = 0

        foreach ($node in $customNodes) {
            $nodeName = $node.Name
            $repoUrl = $node.RepoUrl
            $possiblePath = Join-Path $internalCustomNodes $nodeName

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
                Write-Log "$nodeName already exists." -Level 1 -Color Green
                $successCount++
            }
        }
        Write-Log "Custom nodes installation summary: $successCount processed." -Level 1
    }
    else {
        Write-Log "WARNING: Neither snapshot.json nor custom_nodes.csv were found." -Level 1 -Color Red
    }
}
# UmeAiRT-Sync instalation
$umeSyncPath = Join-Path $internalCustomNodes "ComfyUI-UmeAiRT-Sync"
if (-not (Test-Path $umeSyncPath)) {
    Write-Log "Installing ComfyUI-UmeAiRT-Sync (for workflows auto-update)..." -Level 1 -Color Cyan
    Invoke-AndLog "git" "clone https://github.com/UmeAiRT/ComfyUI-UmeAiRT-Sync.git `"$umeSyncPath`""
    if (Test-Path "$umeSyncPath\requirements.txt") {
        Invoke-AndLog "python" "-m pip install -r `"$umeSyncPath\requirements.txt`""
    }
}
else {
    Write-Log "UmeAiRT Sync Manager already installed." -Level 1 -Color Green
}

# ===========================================================================
# HOTFIX: ComfyUI-MagCache (Line 13 Import Fix)
# ===========================================================================
$magCacheFolder = Join-Path $internalCustomNodes "ComfyUI-MagCache"
$filesToPatch = @("nodes.py", "nodes_calibration.py")

foreach ($fileName in $filesToPatch) {
    $targetFile = Join-Path $magCacheFolder $fileName

    if (Test-Path $targetFile) {
        Write-Log "Applying Hotfix to $fileName (Line 13)..." -Level 1
        try {
            $content = Get-Content -Path $targetFile
            
            # Safety check: Ensure file has enough lines
            if ($content.Count -ge 13) {
                # Modify line 13 (Index 12)
                $content[12] = "from comfy.ldm.lightricks.model import LTXBaseModel"
                
                # Save modifications
                Set-Content -Path $targetFile -Value $content -Encoding UTF8
                Write-Log "Hotfix applied successfully to $fileName." -Level 2 -Color Green
            }
            else {
                Write-Log "WARNING: Could not patch $fileName, file is too short." -Level 2 -Color Yellow
            }
        }
        catch {
            Write-Log "ERROR: Failed to apply hotfix to $fileName." -Level 2 -Color Red
        }
    }
}

# --- CLEANUP ENV VARS ---
$env:PYTHONPATH = $env:PYTHONPATH -replace [regex]::Escape("$comfyPath;"), ""
$env:PYTHONPATH = $env:PYTHONPATH -replace [regex]::Escape("$managerPath;"), ""
$env:COMFYUI_PATH = $null


# --- Step 6: Install GPU-specific optimisations ---
Write-Log "Installing GPU-specific optimisations" -Level 0
# if ($global:hasGpu) {
#     Write-Log "GPU detected, installing GPU-specific repositories..." -Level 1
#    
# Detect CUDA ONLY for compilations
#     $cudaHome = $null
#     $cudaPaths = @(
#         "C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA\v*"
#     )
#     foreach ($pattern in $cudaPaths) {
#         $found = Get-ChildItem -Path $pattern -Directory -ErrorAction SilentlyContinue | 
#                  Sort-Object Name -Descending | Select-Object -First 1
#         if ($found) { $cudaHome = $found.FullName; break }
#     }
#    
#     if ($cudaHome) {
#         $env:CUDA_HOME = $cudaHome
#         $env:PATH = "$(Join-Path $cudaHome 'bin');$env:PATH"
#         Write-Log "CUDA configured for compilation: $cudaHome" -Level 2 -Color Green
#     } else {
#         Write-Log "CUDA Toolkit not found (System) - optional packages ignored if they require compilation" -Level 2 -Color Yellow
#     }
# 
#     foreach ($repo in $dependencies.pip_packages.git_repos) {
#         if (-not $cudaHome -and ($repo.name -match "SageAttention|apex")) {
#             Write-Log "Skipping $($repo.name) (CUDA Toolkit required)" -Level 2 -Color Yellow
#             continue
#         }
#        
#         Write-Log "Attempting to install $($repo.name)..." -Level 2
#         $installUrl = "git+$($repo.url)@$($repo.commit)"
#         $pipArgs = @("-m", "pip", "install")
#         if ($repo.install_options) {
#             $pipArgs += $repo.install_options.Split(' ')
#         }
#         $pipArgs += $installUrl
# 
#         try {
#             # Use $pythonExe
#             $output = & $pythonExe $pipArgs 2>&1
#             if ($LASTEXITCODE -eq 0) {
#                 Write-Log "$($repo.name) installed successfully" -Level 2 -Color Green
# 				
#             } else {
#                 Write-Log "$($repo.name) installation failed (optional)" -Level 2 -Color Yellow
#             }
#         } catch {
#             Write-Log "$($repo.name) installation failed (optional)" -Level 2 -Color Yellow
#         }
#     }
# } else {
#     Write-Log "Skipping GPU-specific git repositories as no GPU was found." -Level 1
# }

Write-Log "Installing packages from .whl files..." -Level 1
foreach ($wheel in $dependencies.pip_packages.wheels) {
    Write-Log "Installing $($wheel.name)" -Level 2
    $wheelPath = Join-Path $scriptPath "$($wheel.name).whl"
     
    try {
        Save-File -Uri $wheel.url -OutFile $wheelPath
        
        if (Test-Path $wheelPath) {
            # Use $pythonExe
            $output = & $pythonExe -m pip install "`"$wheelPath`"" 2>&1
            if ($LASTEXITCODE -eq 0) {
                Write-Log "$($wheel.name) installed successfully" -Level 3 -Color Green
            }
            else {
                Write-Log "$($wheel.name) installation failed (continuing...)" -Level 3 -Color Yellow
            }
            Remove-Item $wheelPath -ErrorAction SilentlyContinue
        }
    }
    catch {
        Write-Log "Failed to download/install $($wheel.name) (continuing...)" -Level 3 -Color Yellow
    }
}

# --- Step 6b: Install Triton and SageAttention (Optimized) ---
Write-Log "Installing Triton and SageAttention (Optimized)..." -Level 1
$installerInfo = $dependencies.files.installer_script
$installerDest = Join-Path $InstallPath $installerInfo.destination

try {
    Save-File -Uri $installerInfo.url -OutFile $installerDest

    if (Test-Path $installerDest) {
        Write-Log "Executing DazzleML Installer..." -Level 2
        Invoke-AndLog $pythonExe "`"$installerDest`" --install --non-interactive --base-path `"$comfyPath`" --python `"$pythonExe`""
    }
    else {
        Write-Log "Failed to download installer script." -Level 2 -Color Red
    }
}
catch {
    Write-Log "Error during optimized installation: $($_.Exception.Message)" -Level 2 -Color Red
}

Write-Log "Downloading cComfyUI custom settings..." -Level 1
$settingsFile = $dependencies.files.comfy_settings
$settingsDest = Join-Path $InstallPath $settingsFile.destination
$settingsDir = Split-Path $settingsDest -Parent
if (-not (Test-Path $settingsDir)) { New-Item -Path $settingsDir -ItemType Directory -Force | Out-Null }
Save-File -Uri $settingsFile.url -OutFile $settingsDest


# --- Step 7: Optional Model Pack Downloads ---
Write-Log "Optional Model Pack Downloads" -Level 0

$modelPacks = @(
    @{Name = "FLUX"; ScriptName = "Download-FLUX-Models.ps1" },
    @{Name = "WAN2.1"; ScriptName = "Download-WAN2.1-Models.ps1" },
    @{Name = "WAN2.2"; ScriptName = "Download-WAN2.2-Models.ps1" },
    @{Name = "HIDREAM"; ScriptName = "Download-HIDREAM-Models.ps1" },
    @{Name = "LTXV"; ScriptName = "Download-LTXV-Models.ps1" },
    @{Name = "QWEN"; ScriptName = "Download-QWEN-Models.ps1" },
    @{Name = "Z-IMAGE"; ScriptName = "Download-Z-IMAGES-Models.ps1" }
)
$scriptsSubFolder = Join-Path $InstallPath "scripts"

foreach ($pack in $modelPacks) {
    $scriptPath = Join-Path $scriptsSubFolder $pack.ScriptName
    if (-not (Test-Path $scriptPath)) {
        Write-Log "Model downloader script not found: '$($pack.ScriptName)'. Skipping." -Level 1 -Color Red
        continue 
    }

    $validInput = $false
    while (-not $validInput) {
        Write-Log "Would you like to download $($pack.Name) models? (Y/N)" -Level 1 -Color Yellow
        $choice = Read-Host

        if ($choice -eq 'Y' -or $choice -eq 'y') {
            Write-Log "Launching downloader for $($pack.Name) models..." -Level 2 -Color Green
            # External script call: We pass InstallPath
            & $scriptPath -InstallPath $InstallPath
            $validInput = $true
        }
        elseif ($choice -eq 'N' -or $choice -eq 'n') {
            Write-Log "Skipping download for $($pack.Name) models." -Level 2
            $validInput = $true
        }
        else {
            Write-Log "Invalid choice. Please enter Y or N." -Level 2 -Color Red
        }
    }
}

#===========================================================================
# FINALIZATION
#===========================================================================
Write-Log "-------------------------------------------------------------------------------" -Color Green
Write-Log "Installation of ComfyUI and all nodes is complete!" -Color Green
Read-Host "Press Enter to close this window."